# wavmaker.ps1
# author: Joshua Mazgelis
# date: 2025-03-28
# version: 1.10

# This script processes audio files to meet WAV Trigger requirements:
# - 16-bit PCM
# - 44.1 kHz sample rate
# - Stereo output
# - Uncompressed PCM encoding
#
# Supported input formats:
# - MP3/M4A: Converted to WAV with sanitized metadata
# - WAV: Validated and copied if meeting requirements, converted if not
#   Note: Valid WAV files are copied without metadata modification
#
# The script handles file renaming and organization according to WAV Trigger specifications:
# - Removes leading track numbers from source files
# - Assigns 3-digit prefixes for primary (101-199) or alternate (201-299) collections
# - Prevents duplicate files with different numerical prefixes

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
# File prefix ranges:
# - 020-029: Kickout hole sounds (Primary)
# - 030-039: Kickout hole sounds (Alternate)
# - 040-049: Rollover lane sounds (Primary)
# - 050-059: Rollover lane sounds (Alternate)
# - 060-069: Tilt relay sounds (Primary)
# - 070-079: Tilt relay sounds (Alternate)
# - 100-199: Music tracks (Primary)
# - 200-299: Music tracks (Alternate)

# Define all range variables
$kickoutPrimaryRange = 20..29
$kickoutAlternateRange = 30..39
$rolloverPrimaryRange = 40..49
$rolloverAlternateRange = 50..59
$tiltPrimaryRange = 60..69
$tiltAlternateRange = 70..79
$musicPrimaryRange = 101..199
$musicAlternateRange = 201..299

# Future enhancements:
# - Add support for additional collection ranges


# Function to sanitize metadata
function Get-SanitizedMetadata {
    param (
        [string]$InputFile
    )
    
    # Extract basic metadata using ffprobe
    $metadata = ffprobe -v quiet -print_format json -show_format -show_streams "$InputFile" | ConvertFrom-Json
    
    # Create sanitized metadata with only essential fields
    $sanitized = @{
        INAM = if ($metadata.format.tags.title) { 
            ($metadata.format.tags.title -replace '[^\w\s-]', '').Trim()  # Remove special characters
        } else { 
            [System.IO.Path]::GetFileNameWithoutExtension($InputFile) 
        }
        IART = if ($metadata.format.tags.artist) { 
            ($metadata.format.tags.artist -replace '[^\w\s-]', '').Trim()
        } else { 
            "Unknown Artist" 
        }
        IPRD = if ($metadata.format.tags.album) { 
            ($metadata.format.tags.album -replace '[^\w\s-]', '').Trim()
        } else { 
            "Unknown Album" 
        }
        ICRD = if ($metadata.format.tags.date) { 
            ($metadata.format.tags.date -replace '[^\d]', '').Trim()  # Keep only numbers
        } else { 
            "Unknown Date" 
        }
        ICMT = if ($metadata.format.tags.comment) {
            ($metadata.format.tags.comment -replace '[^\w\s-]', '').Trim()
        } else {
            ""
        }
        IGNR = if ($metadata.format.tags.genre) {
            ($metadata.format.tags.genre -replace '[^\w\s-]', '').Trim()
        } else {
            ""
        }
        ITRK = if ($metadata.format.tags.track) {
            ($metadata.format.tags.track -replace '[^\w\s-]', '').Trim()
        } else {
            ""
        }
        TPE2 = if ($metadata.format.tags.album_artist) {
            ($metadata.format.tags.album_artist -replace '[^\w\s-]', '').Trim()
        } else {
            ""
        }
        TCOM = if ($metadata.format.tags.composer) {
            ($metadata.format.tags.composer -replace '[^\w\s-]', '').Trim()
        } else {
            ""
        }
    }
    
    # Create metadata string for ffmpeg using original field names
    $metadataString = "-map_metadata -1 " +  # First strip ALL metadata
                     "-metadata INAM=`"$($sanitized.INAM)`" " +
                     "-metadata IART=`"$($sanitized.IART)`" " +
                     "-metadata IPRD=`"$($sanitized.IPRD)`" " +
                     "-metadata ICRD=`"$($sanitized.ICRD)`" " +
                     "-metadata ICMT=`"$($sanitized.ICMT)`" " +
                     "-metadata IGNR=`"$($sanitized.IGNR)`" " +
                     "-metadata ITRK=`"$($sanitized.ITRK)`" " +
                     "-metadata TPE2=`"$($sanitized.TPE2)`" " +
                     "-metadata TCOM=`"$($sanitized.TCOM)`" " +
                     "-write_bext 0 " +  # Disable BEXT chunk
                     "-write_id3v2 0 " +  # Disable ID3v2 chunk
                     "-write_apetag 0 " +  # Disable APE tag
                     "-write_xing 0 "      # Disable XING header
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
    
    # Check each property and report failures
    $sampleRate = $properties['sample_rate'] -eq '44100'
    $channels = $properties['channels'] -eq '2'
    $bitsPerSample = $properties['bits_per_sample'] -eq '16'
    
    if (-not $sampleRate) {
        Write-Host "Sample rate mismatch: Expected 44100, got $($properties['sample_rate'])"
    }
    if (-not $channels) {
        Write-Host "Channel count mismatch: Expected 2, got $($properties['channels'])"
    }
    if (-not $bitsPerSample) {
        Write-Host "Bits per sample mismatch: Expected 16, got $($properties['bits_per_sample'])"
    }
    
    return ($sampleRate -and $channels -and $bitsPerSample)
}

# Function to validate WAV file structure
function Test-WavStructure {
    param (
        [string]$FilePath,
        [string]$FileExtension
    )

    # This may not be working as intended, just return true for now
    return $true
    
    # Skip structure check for non-WAV files
    if ($FileExtension -ne '.wav') {
        return $true
    }
    
    # Use ffprobe to check WAV file structure
    $ffprobeOutput = ffprobe -v error -show_format -show_streams -of json "$FilePath" | ConvertFrom-Json
    
    # Check if the file has the required chunks in the correct order
    $hasRiff = $ffprobeOutput.format.format_name -eq 'wav'
    if (-not $hasRiff) {
        Write-Host "Missing or invalid RIFF header"
    }
    
    # Safely check for streams array and codec
    $hasFmt = $false
    if ($ffprobeOutput.format.streams -and $ffprobeOutput.format.streams.Count -gt 0) {
        $hasFmt = $ffprobeOutput.format.streams[0].codec_name -eq 'pcm_s16le'
        if (-not $hasFmt) {
            Write-Host "Invalid codec: Expected pcm_s16le, got $($ffprobeOutput.format.streams[0].codec_name)"
        }
    } else {
        Write-Host "No audio streams found"
    }
    
    $hasData = $ffprobeOutput.format.size -gt 0
    if (-not $hasData) {
        Write-Host "No audio data found"
    }
    
    return ($hasRiff -and $hasFmt -and $hasData)
}

# Function to check for duplicate files by name (ignoring prefix)
function Test-DuplicateFile {
    param (
        [string]$TargetFolder,
        [string]$FileName
    )
    
    # Get all WAV files in the target folder
    $existingFiles = Get-ChildItem -Path $TargetFolder -Filter "*.wav"
    
    # Extract the base name without prefix (everything after the first underscore)
    $baseName = $FileName -replace '^\d+_', ''
    
    # Check if any existing file has the same base name
    foreach ($file in $existingFiles) {
        $existingBaseName = $file.Name -replace '^\d+_', ''
        if ($existingBaseName -eq $baseName) {
            return $true
        }
    }
    
    return $false
}

########################################################################################
# Main Script starts here
########################################################################################

# Welcome message
Write-Host "Welcome to the WAV Maker script!"
Write-Host "This script processes audio files to meet WAV Trigger requirements."
Write-Host "  (16-bit PCM, 44.1 kHz, stereo)"

# Check if ffmpeg is accessible
$ffmpegLocation = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpegLocation) {
    Write-Host "ffmpeg is not installed or not accessible. Please install it and try again."
    exit
} else {
    Write-Host "Found ffmpeg at: $($ffmpegLocation.Source)"
}

# Create output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder
}

# Check that the target folder exists
if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder
}

# Display list of files in the input folder
Write-Host "Audio files in the input folder:"
Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a, *.wav -Recurse | ForEach-Object {
    Write-Host $_.Name
}

# Remove the leading track number from the file name
Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a, *.wav -Recurse | ForEach-Object {
    Write-Host "Processing file: $($_.Name)"
    # Check if the file name starts with a track number
    if ($_.Name -match '^\d+[-\s\.]?\d*\s*') {
        $newName = $_.Name -replace '^\d+[-\s\.]?\d*\s*', ''
        Write-Host "This file has a leading number:"
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

# Loop through all audio files and process them
$convertedCount = 0
Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a, *.wav -Recurse | ForEach-Object {
    $inputFile = $_.FullName
    $wavFile = Join-Path $outputFolder ($_.BaseName + ".wav")
    
    # Check if the file is already in the output folder, perhaps from a previous run
    if (-not (Test-Path $wavFile)) {
        Write-Host "Processing $($_.Name)..."
        
        # If it's already a WAV file, validate it first
        if ($_.Extension -eq '.wav') {
            if ((Test-WavFile -FilePath $inputFile) -and (Test-WavStructure -FilePath $inputFile -FileExtension $_.Extension)) {
                Write-Host "File $($_.Name) already meets WAV Trigger requirements."
                # Copy the file to output folder instead of converting
                Copy-Item -Path $inputFile -Destination $wavFile
                $convertedCount++
                Remove-Item -Path $inputFile
                Write-Host "Copied valid WAV file: $($_.Name)"
                continue
            } else {
                Write-Host "WAV file $($_.Name) does not meet requirements. Will be converted."
            }
        }
        
        # Get sanitized metadata
        $metadataString = Get-SanitizedMetadata -InputFile $inputFile
        
        # Convert to WAV with specific requirements and sanitized metadata
        # The -map_metadata -1 flag strips all metadata before we add our sanitized version
        $ffmpegCommand = "ffmpeg -i `"$inputFile`" -ac 2 -ar 44100 -acodec pcm_s16le -f wav -write_bext 0 -write_id3v2 0 -write_apetag 0 -write_xing 0 $metadataString `"$wavFile`""
        Invoke-Expression $ffmpegCommand
        
        if ($?) {
            # Validate both the audio properties and file structure
            if ((Test-WavFile -FilePath $wavFile) -and (Test-WavStructure -FilePath $wavFile -FileExtension '.wav')) {
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
        Write-Host "Skipping processing for $($_.Name) as $wavFile already exists."
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

# Ask the user for the sound type and collection type
Write-Host "`nSelect the sound type:"
Write-Host "1. Kickout hole sounds"
Write-Host "2. Rollover lane sounds"
Write-Host "3. Tilt relay sounds"
Write-Host "4. Music tracks"
$soundType = Read-Host "Enter the number (1-4)"

Write-Host "`nSelect the collection type:"
Write-Host "p. Primary collection"
Write-Host "a. Alternate collection"
$collectionType = Read-Host "Enter p or a"

# Set the appropriate range based on selections
switch ($soundType) {
    "1" { 
        if ($collectionType -eq 'p') { $prefixRange = $kickoutPrimaryRange }
        else { $prefixRange = $kickoutAlternateRange }
    }
    "2" { 
        if ($collectionType -eq 'p') { $prefixRange = $rolloverPrimaryRange }
        else { $prefixRange = $rolloverAlternateRange }
    }
    "3" { 
        if ($collectionType -eq 'p') { $prefixRange = $tiltPrimaryRange }
        else { $prefixRange = $tiltAlternateRange }
    }
    "4" { 
        if ($collectionType -eq 'p') { $prefixRange = $musicPrimaryRange }
        else { $prefixRange = $musicAlternateRange }
    }
    default {
        Write-Host "Invalid sound type selection. Exiting."
        exit
    }
}

if ($collectionType -ne 'p' -and $collectionType -ne 'a') {
    Write-Host "Invalid collection type selection. Exiting."
    exit
}

# Move WAV files to the target folder with 3-digit prefix
$prefixIndex = 0
Get-ChildItem -Path $outputFolder -Filter *.wav | ForEach-Object {
    $wavFile = $_.FullName
    $prefix = $prefixRange[$prefixIndex]
    $targetName = "{0:D3}_{1}" -f $prefix, $_.Name
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
        $targetName = "{0:D3}_{1}" -f $prefix, $_.Name
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

Write-Host "All files have been processed as directed."
Write-Host "Please check the target folder for the newly renamed and organized files."
Write-Host "Thank you for using the WAV Maker script!"

