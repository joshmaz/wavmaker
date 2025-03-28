# wavmaker.ps1
# author: Joshua Mazgelis
# date: 2025-03-28
# version: 1.3

# This script converts MP3/M4A files to WAV format meeting WAV Trigger requirements:
# - 16-bit PCM
# - 44.1 kHz sample rate
# - Stereo output
# - Uncompressed PCM encoding
# It also handles file renaming and organization according to WAV Trigger specifications.

# Set the path to the ffmpeg executable
$ffmpegPath = "C:\ProgramData\chocolatey\lib\ffmpeg\tools\ffmpeg\bin\ffmpeg.exe"

# Set working directory to the folder containing the MP3 files
$inputFolder = ".\MP3s"
$outputFolder = ".\WAVs"

# Set target folder for WAV files
$targetFolder = "C:\Users\joshm\OneDrive\Documents\WAV Trigger\Chicago Coin Playboy"

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
        
        # Convert to WAV with specific requirements
        ffmpeg -i "$inputFile" -ac 2 -ar 44100 -acodec pcm_s16le -map_metadata 0 "$wavFile"
        
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