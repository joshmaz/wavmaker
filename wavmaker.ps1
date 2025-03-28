# wavmaker.ps1
# author: Joshua Mazgelis
# date: 2025-03-28
# version: 1.7

# This script converts MP3/M4A files to WAV format meeting WAV Trigger requirements:
# - 16-bit PCM
# - 44.1 kHz sample rate
# - Stereo output
# - Uncompressed PCM encoding
# It also handles file renaming and organization according to WAV Trigger specifications.

# Set the path to the ffmpeg executable
$ffmpegPath = "C:\ProgramData\chocolatey\lib\ffmpeg\tools\ffmpeg\bin\ffmpeg.exe"

# Set working directory to the folder containing the source files
$inputFolder = ".\Source_Files"
$outputFolder = ".\WAVs"

# Set target folder for WAV files
$targetFolder = "C:\Users\joshm\OneDrive\Documents\WAV Trigger\Chicago Coin Playboy"

# Target Folder Strategy:
# This script writes directly to the target folder to maintain a consistent numerical sequence
# and prevent duplicate tracks. When files are removed from the target directory, this approach
# allows new files to fill in the gaps numerically. Additionally, it enables checking for existing
# tracks with the same name to prevent accidental duplicates with different numerical prefixes.

# Set range numbers for primary and alternate track collections
$primaryRange = 101..199
$alternateRange = 201..299

# Create output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder
}

# Check if ffmpeg is installed
if (-not (Test-Path $ffmpegPath)) {
    Write-Host "ffmpeg is not installed. Please install it and try again."
    exit
}

# Add ffmpeg to the system PATH
$env:PATH += ";$($ffmpegPath)"
# Check if ffmpeg is accessible
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ffmpeg is not accessible. Please check your PATH."
    exit
}

# Function to sanitize metadata
function Get-SanitizedMetadata {
    param (
        [string]$InputFile
    )
    
    # Extract basic metadata using ffprobe
    $metadata = ffprobe -v quiet -print_format json -show_format -show_streams "$InputFile" | ConvertFrom-Json
    
    # Create sanitized metadata with only essential fields
    $sanitized = @{
        title = if ($metadata.format.tags.title) { 
            ($metadata.format.tags.title -replace '[^\w\s-]', '').Trim()  # Remove special characters
        } else { 
            [System.IO.Path]::GetFileNameWithoutExtension($InputFile) 
        }
        artist = if ($metadata.format.tags.artist) { 
            ($metadata.format.tags.artist -replace '[^\w\s-]', '').Trim()
        } else { 
            "Unknown Artist" 
        }
        album = if ($metadata.format.tags.album) { 
            ($metadata.format.tags.album -replace '[^\w\s-]', '').Trim()
        } else { 
            "Unknown Album" 
        }
        date = if ($metadata.format.tags.date) { 
            ($metadata.format.tags.date -replace '[^\d]', '').Trim()  # Keep only numbers
        } else { 
            "Unknown Date" 
        }
    }
    
    # Create metadata string for ffmpeg using original field names
    $metadataString = "-map_metadata -1 " +  # First strip ALL metadata
                     "-metadata title=`"$($sanitized.title)`" " +
                     "-metadata artist=`"$($sanitized.artist)`" " +
                     "-metadata album=`"$($sanitized.album)`" " +
                     "-metadata date=`"$($sanitized.date)`" "
    
    return $metadataString
}

# Function to validate WAV file
function Test-WavFile {
    param (
        [string]$FilePath
    )
    
    # Use ffprobe to check WAV file properties
    $ffprobeOutput = ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate,channels,bits_per_sample -of default=noprint_wrappers=1 "$FilePath"
    
    # Parse the output
    $properties = @{}
    $ffprobeOutput | ForEach-Object {
        $key, $value = $_ -split '='
        $properties[$key] = $value
    }
    
    # Check if all required properties are present and correct
    return ($properties['sample_rate'] -eq '44100' -and
            $properties['channels'] -eq '2' -and
            $properties['bits_per_sample'] -eq '16')
}

# Function to check for duplicate files by name (ignoring prefix)
function Test-DuplicateFile {
    param (
        [string]$TargetFolder,
        [string]$FileName
    )
    
    # Get all WAV files in the target folder
    $existingFiles = Get-ChildItem -Path $TargetFolder -Filter "*.wav"
    
    # Extract the base name without prefix (everything after the first hyphen)
    $baseName = $FileName -replace '^\d+-', ''
    
    # Check if any existing file has the same base name
    foreach ($file in $existingFiles) {
        $existingBaseName = $file.Name -replace '^\d+-', ''
        if ($existingBaseName -eq $baseName) {
            return $true
        }
    }
    
    return $false
}

# Remove the leading track number from the file name
Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a -Recurse | ForEach-Object {
    Write-Host "Processing file: $($_.Name)"
    # Check if the file name starts with a track number
    if ($_.Name -match '^\d+[-\s]?\d+\s*') {
        $newName = $_.Name -replace '^\d+[-\s]?\d+\s*', ''
        Write-Host "This file has a leading disc & track number:"
        Write-Host "Old Name: $($_.Name)"
        Write-Host "New Name: $newName"
        $confirmation = Read-Host "Do you want to rename this file? (y/n)"
        if ($confirmation -eq 'y') {
            Rename-Item -Path $_.FullName -NewName $newName
        } else {
            Write-Host "Skipping rename for: $($_.Name)"
        }
    } elseif ($_.Name -match '^\d+\s*') {
        $newName = $_.Name -replace '^\d+\s*', ''
        Write-Host "This file has a leading track number:"
        Write-Host "Old Name: $($_.Name)"
        Write-Host "New Name: $newName"
        $confirmation = Read-Host "Do you want to rename this file? (y/n)"
        if ($confirmation -eq 'y') {
            Rename-Item -Path $_.FullName -NewName $newName
        } else {
            Write-Host "Skipping rename for: $($_.Name)"
        }
    }
}

# Loop through all MP3/M4A files and convert them to WAV format
$convertedCount = 0
Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a -Recurse | ForEach-Object {
    $inputFile = $_.FullName
    $wavFile = Join-Path $outputFolder ($_.BaseName + ".wav")
    
    if (-not (Test-Path $wavFile)) {
        Write-Host "Converting $($_.Name) to WAV format..."
        
        # Get sanitized metadata
        $metadataString = Get-SanitizedMetadata -InputFile $inputFile
        
        # Convert to WAV with specific requirements and sanitized metadata
        # The -map_metadata -1 flag strips all metadata before we add our sanitized version
        $ffmpegCommand = "ffmpeg -i `"$inputFile`" -ac 2 -ar 44100 -acodec pcm_s16le $metadataString `"$wavFile`""
        Invoke-Expression $ffmpegCommand
        
        if ($?) {
            # Validate the converted WAV file
            if (Test-WavFile -FilePath $wavFile) {
                $convertedCount++
                Remove-Item -Path $inputFile
                Write-Host "Successfully converted and validated $($_.Name)"
            } else {
                Write-Host "WAV file validation failed for $($_.Name). The file may not meet WAV Trigger requirements."
                Remove-Item -Path $wavFile
            }
        } else {
            Write-Host "Conversion failed for $($_.Name)"
        }
    } else {
        Write-Host "Skipping conversion for $($_.Name) as $wavFile already exists."
    }
}

# Check if any files were converted
if ($convertedCount -eq 0) {
    Write-Host "No files were converted."
    exit
}
Write-Host "$convertedCount files were converted to WAV format."

# Get the list of WAV files in the output folder
$wavFiles = Get-ChildItem -Path $outputFolder -Filter *.wav
if ($wavFiles.Count -eq 0) {
    Write-Host "No WAV files found in the output folder."
    exit
}

# Display the list of WAV files
Write-Host "WAV files in the output folder:"
foreach ($file in $wavFiles) {
    Write-Host $file.Name
}

# Ask the user if these are for the primary or alternate track collection
$collectionType = Read-Host "Are these for the primary (p) or alternate (a) track collection? (p/a)"
if ($collectionType -eq 'p') {
    $prefixRange = $primaryRange
} elseif ($collectionType -eq 'a') {
    $prefixRange = $alternateRange
} else {
    Write-Host "Invalid selection. Exiting."
    exit
}

# Move WAV files to the target folder with 3-digit prefix
$prefixIndex = 0
Get-ChildItem -Path $outputFolder -Filter *.wav | ForEach-Object {
    $wavFile = $_.FullName
    $prefix = $prefixRange[$prefixIndex]
    $targetName = "{0:D3}-{1}" -f $prefix, $_.Name
    $targetPath = Join-Path $targetFolder $targetName
    
    # Check for duplicate files by name (ignoring prefix)
    if (Test-DuplicateFile -TargetFolder $targetFolder -FileName $targetName) {
        Write-Host "Warning: A file with the same name already exists in the target folder:"
        Write-Host "File: $($_.Name)"
        $confirmation = Read-Host "Do you want to skip this file? (y/n)"
        if ($confirmation -eq 'y') {
            Write-Host "Skipping duplicate file: $($_.Name)"
            continue
        }
    }
    
    # Check if a file with the target prefix already exists
    while (Get-ChildItem -Path $targetFolder -Filter "$prefix-*.wav") {
        $prefixIndex++
        if ($prefixIndex -ge $prefixRange.Count) {
            Write-Host "No more available prefixes in the selected range. Exiting."
            exit
        }
        $prefix = $prefixRange[$prefixIndex]
        $targetName = "{0:D3}-{1}" -f $prefix, $_.Name
        $targetPath = Join-Path $targetFolder $targetName
    }

    Write-Host "Old Name: $($_.Name)"
    Write-Host "Target Name: $targetName"
    $confirmation = Read-Host "Do you want to move and rename this file? (y/n)"
    if ($confirmation -eq 'y') {
        Move-Item -Path $wavFile -Destination $targetPath
        $prefixIndex++
    } else {
        Write-Host "Skipping file: $($_.Name)"
    }
}