# wavmaker.ps1
# author: Joshua Mazgelis
# date: 2025-04-01
# version: 1.15

[CmdletBinding()]
param()

# This script processes audio files to meet WAV Trigger requirements:
# - 16-bit PCM
# - 44.1 kHz sample rate
# - Stereo output
# - Uncompressed PCM encoding
#
# Supported input formats:
# - MP3/M4A/WAV files
#
# The script handles file renaming and organization according to project specifications:
# - Removes leading track numbers from source files
# - Assigns 3-digit prefixes for primary (101-199) or alternate (201-299) collections
# - Prevents duplicate files with different numerical prefixes

# Set working directory to the folder containing the source files
$inputFolder = ".\Source_Files"
$outputFolder = ".\WAVs"

# Target Folder Strategy:
# This script writes directly to the target folder to maintain a consistent numerical sequence
# and prevent duplicate tracks. When files are removed from the target directory, this approach
# allows new files to fill in the gaps numerically. Additionally, it enables checking for existing
# tracks with the same name to prevent accidental duplicates with different numerical prefixes.

# This is the folder that will contain the WAV files after they are converted and renamed with the 3-digit prefix
$targetFolder = "C:\Users\joshm\OneDrive\Documents\WAV Trigger\Chicago Coin Playboy"
# The Target Folder will be unique for each project, so it will need to be set for each project
# In my workflow, this target folder contains everything that will be uploaded to the WAV Trigger via the microSD card
# The script will check for the existence of the target folder and will prompt the user to create it or specify a different folder

# Set range numbers for primary and alternate track collections
# File prefix ranges:
# - 021-029: Kickout hole sounds (Primary)
# - 031-039: Kickout hole sounds (Alternate)
# - 041-049: Rollover lane sounds (Primary)
# - 051-059: Rollover lane sounds (Alternate)
# - 061-069: Tilt relay sounds (Primary)
# - 071-079: Tilt relay sounds (Alternate)
# - 101-199: Music tracks (Primary)
# - 201-299: Music tracks (Alternate)

# Define the scopes for all range variables
$kickoutPrimaryRange = 21..29
$kickoutAlternateRange = 31..39
$rolloverPrimaryRange = 41..49
$rolloverAlternateRange = 51..59
$tiltPrimaryRange = 61..69
$tiltAlternateRange = 71..79
$musicPrimaryRange = 101..199
$musicAlternateRange = 201..299

# I used behavior flags to make the script more flexible and easier to modify
# A proper command line interface would be better, but this is a quick and dirty solution
# Behavior Option Flags:

# - Remove leading track numbers from file names without asking the user
$optionRemoveLeadingTrackNumbers = $true

# - Sanitize metadata
$optionSanitizeMetadata = $false

# - Validate WAV file properties and structure
$optionValidateWavFile = $false

# - Check for duplicate files by name (ignoring prefix)
$optionCheckForDuplicateFiles = $true

# - Display ffmpeg configuration header
$optionDisplayFfmpegConfigHeader = $false

# - Display list of files in the input folder
$optionDisplayInputFiles = $true

# - Confirm file move and rename for each file after processing
$optionConfirmFileMoveAndRename = $false

# - Default conversion software to use, ffmpeg or sox or audacity
$optionDefaultConversionSoftware = "ffmpeg"

# - Default post-processing software to use, sox or audacity
$optionDefaultPostProcessingSoftware = "audacity"

# - Use an intermediary file format for post-processing with audacity
# - Make this a null string if you don't want to use an intermediary file format (not yet tested)
# - Tested with: FLAC
$optionIntermediaryFileFormat = "FLAC"

# - Copy valid WAV files to the target folder
# - If this is set not true then all WAV files will be reprocessed and not validated & copied
$optionCopyValidWAVs = $true

# - Audacity macro outputfolder
# - This is the folder that will contain the Audacity macro output files (The WAV files)
# - This is a relative path, and it will be combined with the user's profile path
$optionAudacityMacroOutputFolder = "OneDrive\Documents\Audacity\macro-output"

# - Audactity macro location
# - This is the location of the Audacity macro that will be used to process the audio files
# - We used to merge the environment path in the main script, but it simplified the code to just include it here
$optionAudacityMacroLocation = "$env:APPDATA\audacity\Macros\AutoWAVMaker.txt"

########################################################################################
# End of configuration section
########################################################################################    

# Function to sanitize metadata
function Get-SanitizedMetadata {
    param (
        [string]$InputFile
    )
    
    # Extract basic metadata using ffprobe
    $metadata = ffprobe -v quiet -print_format json -show_format -show_streams "$InputFile" | ConvertFrom-Json
    Write-Debug "Extracted metadata: $metadata"
    
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
    
    # Display metadata in debug mode
    Write-Debug "`nSanitized metadata for $([System.IO.Path]::GetFileName($InputFile)):"
    Write-Debug "----------------------------------------"
    $sanitized.GetEnumerator() | ForEach-Object {
        Write-Debug "$($_.Key): $($_.Value)"
    }
    Write-Debug "----------------------------------------`n"
    
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
    Write-Debug "Testing WAV file: $FilePath"

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
    Write-Debug "Testing WAV file structure: $FilePath"
    
    # Skip structure check for non-WAV files
    if ($FileExtension -ne '.wav') {
        Write-Debug "Skipping structure check for non-WAV file: $FilePath"
        return $true
    }
    
    # Use ffprobe to check WAV file structure
    $ffprobeOutput = ffprobe -v error -show_format -show_streams -of json "$FilePath"
    Write-Debug "Raw FFprobe output: $ffprobeOutput"
    
    try {
        $ffprobeData = $ffprobeOutput | ConvertFrom-Json
        Write-Debug "Parsed FFprobe data:"
        Write-Debug "Format name: $($ffprobeData.format.format_name)"
        Write-Debug "Format size: $($ffprobeData.format.size)"
        Write-Debug "Number of streams: $($ffprobeData.streams.Count)"
        
        # Check if the file has the required chunks in the correct order
        $hasRiff = $ffprobeData.format.format_name -eq 'wav'
        if (-not $hasRiff) {
            Write-Host "Missing or invalid RIFF header"
        }
        
        # Safely check for streams array and codec
        $hasFmt = $false
        if ($ffprobeData.streams -and $ffprobeData.streams.Count -gt 0) {
            $hasFmt = $ffprobeData.streams[0].codec_name -eq 'pcm_s16le'
            if (-not $hasFmt) {
                Write-Host "Invalid codec: Expected pcm_s16le, got $($ffprobeData.streams[0].codec_name)"
            }
        } else {
            Write-Host "No audio streams found"
        }
        
        $hasData = $ffprobeData.format.size -gt 0
        if (-not $hasData) {
            Write-Host "No audio data found"
        }
        
        return ($hasRiff -and $hasFmt -and $hasData)
    } catch {
        Write-Debug "Error parsing FFprobe output: $_"
        Write-Host "Error analyzing WAV file structure: $_"
        return $false
    }
}

# Function to check for duplicate files by name (ignoring prefix)
function Test-DuplicateFile {
    param (
        [string]$TargetFolder,
        [string]$FileName
    )
    
    Write-Debug "Checking for duplicate files in $TargetFolder"
    Write-Debug "File name: $FileName"

    # Get all WAV files in the target folder
    $existingFiles = Get-ChildItem -Path $TargetFolder -Filter "*.wav"
    
    # Extract the base name without prefix (everything after the first underscore)
    $baseName = $FileName -replace '^\d+[_-]', ''
    Write-Debug "Base name: $baseName"
    
    # Check if any existing file has the same base name
    foreach ($file in $existingFiles) {
        $existingBaseName = $file.Name -replace '^\d+[_-]', ''
        Write-Debug "Existing base name: $existingBaseName"
        if ($existingBaseName -eq $baseName) {
            return @{
                HasConflict = $true
                ConflictingFile = $file.FullName
                ConflictingName = $file.Name
            }
        }
    }
    
    return @{
        HasConflict = $false
        ConflictingFile = $null
        ConflictingName = $null
    }
}

function Write-AudioFileProperties {
    param (
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )
    
    $fileInfo = ffprobe -v quiet -print_format json -show_format -show_streams "$FilePath" | ConvertFrom-Json
    Write-Debug " File size: $([math]::Round($fileInfo.format.size / 1MB, 2)) MB"
    Write-Debug " Duration: $([math]::Round($fileInfo.format.duration, 2)) seconds" 
    Write-Debug " Bit rate: $([math]::Round($fileInfo.format.bit_rate / 1000, 2)) kbps"
    Write-Debug " Sample rate: $($fileInfo.streams[0].sample_rate) Hz"
    Write-Debug " Channels: $($fileInfo.streams[0].channels)"
    Write-Debug " Bits per sample: $($fileInfo.streams[0].bits_per_sample)"
    Write-Debug " Codec: $($fileInfo.streams[0].codec_name)"
}

########################################################################################
# Main Script starts here
########################################################################################

Write-Host "`nWelcome to the WAV Maker script!" -ForegroundColor Green
Write-Host "This script processes audio files to meet WAV Trigger requirements."
Write-Host "  (16-bit PCM, 44.1 kHz, stereo)"

# Enable debug output with -Debug switch when running script
Write-Debug "Debug mode is enabled."

# Check if supported conversion software is installed and accessible
$ffmpegLocation = Get-Command ffmpeg -ErrorAction SilentlyContinue
$soxLocation = Get-Command sox -ErrorAction SilentlyContinue        # sox only supports WAV file inputs

if (-not $ffmpegLocation -and -not $soxLocation) {
    Write-Host "Neither ffmpeg nor sox is installed or not accessible. Please install one of them and try again." -ForegroundColor Red
    exit
} elseif (-not $ffmpegLocation -and $soxLocation) {
    Write-Debug "Using sox for audio conversion as ffmpeg is not installed."
    Write-Host "Using sox for audio conversion. Only WAV files are supported as input."
    $optionDefaultConversionSoftware = "sox"
} elseif ($ffmpegLocation -and -not $soxLocation) {
    Write-Debug "Using ffmpeg for audio conversion as sox is not installed."
    $optionDefaultConversionSoftware = "ffmpeg"
} else {
    Write-Debug "Both ffmpeg and sox are installed. Using the default conversion software: $optionDefaultConversionSoftware"
}

# Check if audacity is installed in one of these common locations
$audacityLocations = @(
    "C:\Program Files\Audacity\audacity.exe",
    "C:\Program Files (x86)\Audacity\audacity.exe",
    "C:\tools\audacity\audacity.exe",  # Chocolatey default location
    "C:\ProgramData\chocolatey\bin\audacity.exe"  # Chocolatey alternative location
)

$audacityLocation = $null
foreach ($location in $audacityLocations) {
    if (Test-Path $location) {
        $audacityLocation = $location
        Write-Debug "Found Audacity at: $location"
        break
    }
}

if (-not $audacityLocation) {
    Write-Host "Audacity is not installed in any of the common locations. Please install it and try again." -ForegroundColor Red
    Write-Host "Common installation locations checked:"
    foreach ($location in $audacityLocations) {
        Write-Host "  $location"
    }
    exit
}

# Check that the AutoWAVMaker macro exists
$audacityMacroLocation = $optionAudacityMacroLocation # This is redundant now that we're merging the environment path in the configuration section
if (-not (Test-Path $audacityMacroLocation)) {
    Write-Host "AutoWAVMaker macro does not exist at $audacityMacroLocation"
    Write-Host "Would you like me to attempt to create it for you?"
    $confirmation = Read-Host "Enter y or n"
    if ($confirmation -eq 'y') {
        New-Item -ItemType File -Path $audacityMacroLocation
        # Write the AutoWAVMaker macro content
        @"
SelectAll:
Normalize:ApplyVolume="1" PeakLevel="-1" RemoveDcOffset="1" StereoIndependent="0"
ExportWav:
"@ | Out-File -FilePath $audacityMacroLocation -Encoding UTF8

        Write-Host "AutoWAVMaker macro created at $audacityMacroLocation" -ForegroundColor Green
    } else {
        Write-Debug "AutoWAVMaker macro does not exist at $audacityMacroLocation"
    }
}

# Create output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder
    Write-Host "Output folder created: $outputFolder"
} else {
    Write-Debug "Using output folder: $outputFolder"
}

# Ensure that the target folder exists
$validTargetFolder = $false
while (-not $validTargetFolder) {
    if (-not (Test-Path $targetFolder)) {
        Write-Host "Target folder does not exist at $targetFolder" -ForegroundColor Yellow
        Write-Host "Would you like to create this folder or specify a different folder?"
        $confirmation = Read-Host "Enter y to create the folder or n to specify a different folder"
        if ($confirmation -eq 'y') {
            New-Item -ItemType Directory -Path $targetFolder
            Write-Host "Target folder created: $targetFolder"
            $validTargetFolder = $true
        } else {
            Write-Host "Please specify a different target folder."
            $targetFolder = Read-Host "Enter the target folder"
            if (Test-Path $targetFolder) {
                $validTargetFolder = $true
            }
        }
    } else {
        Write-Debug "Using target folder: $targetFolder"
        $validTargetFolder = $true
    }
}

# Display list of files in the input folder
if ($optionDisplayInputFiles) {
    # Get all audio files in the input folder
    $audioFiles = Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a, *.wav -Recurse
    
    # Check if there are any files
    if ($audioFiles.Count -eq 0) {
        Write-Host "No audio files found in the input folder." -ForegroundColor Yellow
    } else {
        # Display the list of files
        Write-Host "`nAudio files in the input folder:" -ForegroundColor Green
        foreach ($file in $audioFiles) {
            Write-Host "  $($file.Name)" -ForegroundColor Blue
        }
        # Ask for confirmation
        Write-Host "`nAre these the files you wish to process? (y/n)"
        $confirmation = Read-Host "Enter y or n"
        if ($confirmation -eq 'n') {
            Write-Host "Okay, I'll exit the script. Please run it again when you're ready to process the input folder."
            exit
        }
    }
}

# Ask the user to define the type of sound and collection, and therefore the prefix range
while ($prefixRange.Count -eq 0) {
    Write-Host "`nThe target files will be named with a 3-digit prefix corresponding to the sound type and collection type."
    Write-Host "`nSelect the sound type:"
    Write-Host " 1. Kickout hole sounds"
    Write-Host " 2. Rollover lane sounds"
    Write-Host " 3. Tilt relay sounds"
    Write-Host " 4. Music tracks"
    $soundType = Read-Host "Enter the number for the sound type we're processing (1-4)"

    Write-Host "`nSelect the collection type:"
    Write-Host " p. Primary collection"
    Write-Host " a. Alternate collection"
    $collectionType = Read-Host "Enter p or a to specify if these should be added to the primary or alternate collection"

    Write-Debug "User entered sound type: $soundType and collection type: $collectionType"

    # Set the appropriate range based on selections
    switch ($soundType) {
        "1" { 
            if ($collectionType -eq 'p') { 
                $prefixRange = $kickoutPrimaryRange 
                Write-Host "Selected sound type: Kickout hole sounds (Primary collection)"
            }
            else { 
                $prefixRange = $kickoutAlternateRange 
                Write-Host "Selected sound type: Kickout hole sounds (Alternate collection)"
            }
        }
        "2" { 
            if ($collectionType -eq 'p') { 
                $prefixRange = $rolloverPrimaryRange 
                Write-Host "Selected sound type: Rollover lane sounds (Primary collection)"
            }
            else { 
                $prefixRange = $rolloverAlternateRange 
                Write-Host "Selected sound type: Rollover lane sounds (Alternate collection)"
            }
        }
        "3" { 
            if ($collectionType -eq 'p') { 
                $prefixRange = $tiltPrimaryRange 
                Write-Host "Selected sound type: Tilt relay sounds (Primary collection)"
            }
            else { 
                $prefixRange = $tiltAlternateRange 
                Write-Host "Selected sound type: Tilt relay sounds (Alternate collection)"
            }
        }
        "4" { 
            if ($collectionType -eq 'p') { 
                $prefixRange = $musicPrimaryRange 
                Write-Host "Selected sound type: Music tracks (Primary collection)"
            }
                else { 
                $prefixRange = $musicAlternateRange 
                Write-Host "Selected sound type: Music tracks (Alternate collection)"
            }
        }
        default {
            Write-Host "Invalid sound type selection."
            Write-Host "Would you like to enter the prefix range manually?"
            $confirmation = Read-Host "Enter y or n"
            if ($confirmation -eq 'y') {
                # The format of the prefix range is a scope of numbers, for example: 100..199
                Write-Host "Please enter the prefix range as a scope of numbers, for example: 100..199"
                $prefixRange = Read-Host "Enter the prefix range"
            } else {
                $prefixRange = @()
                exit
            }
        }
    }
    Write-Debug "Prefix range: $prefixRange"
}

# Clean up the input folder before the conversion process so that we're entering with clean filenames
if ($optionRemoveLeadingTrackNumbers) {
    Write-Host "`nRemoving leading disc/track numbers from input files..." -ForegroundColor Green
    Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a, *.wav -Recurse | ForEach-Object {
        if ($_.Name -match '^\d+[-\s\.]?\d*\s*') {
            $newName = $_.Name -replace '^\d+[-\s\.]?\d*\s*', ''
        Write-Host "This file appears to have a leading disc/track number that will be removed:"
        Write-Host " Old Name: $($_.Name)"
        Write-Host " New Name: $newName"

        # Commented out for now, just rename the file without asking for confirmation
        # $confirmation = Read-Host "Do you want to rename this file? (y/n)"
        $confirmation = 'y'
        if ($confirmation -eq 'y') {
            Rename-Item -Path $_.FullName -NewName $newName
            } else {
                Write-Host "Skipping rename for: $($_.Name)"
            }
        } else {
            Write-Debug "No leading disc/track numbers found in: $($_.Name)"
        }
    }
} # End of removing leading disc/track numbers

# Loop through all audio files and process them
$convertedCount = 0
$conversionSkippedCount = 0

Write-Host "`nProcessing audio files..." -ForegroundColor Green
Get-ChildItem -Path $inputFolder -Include *.mp3, *.m4a, *.wav -Recurse | ForEach-Object {
    Write-Host "`nProcessing file: $($_.Name)" -ForegroundColor Blue

    # Get the input file path
    $inputFile = $_.FullName
    Write-Debug "Input file: $inputFile"

    # This is a flag to indicate if the input file is a valid WAV file
    $inputFileValidWAV = $false

    # Create the output file target path with appropriate extension. This is the file that will be created.
    $outputFile = Join-Path $outputFolder ($_.BaseName + ".$($optionIntermediaryFileFormat.ToLower())")
    Write-Debug "Output file target: $outputFile"

    # Check if the file is already in the output folder, perhaps from a previous run
    if (Test-Path $outputFile) {
        Write-Host "Skipping processing for $($_.Name) as $outputFile already exists in the output folder." -ForegroundColor Yellow
        $conversionSkippedCount++
        continue
    }

    Write-Host "Processing $($_.Name)..."
        
    # If it's already a WAV file, optionally validate it and copy it to the output folder instead of converting
    # My validation tests are not fully reliable, so we'll not skip processing if it's already a WAV file
    if ($_.Extension -eq '.wav' -and $optionCopyValidWAVs -eq $true) {
        Write-Debug "File is already a WAV file: $($_.Name)"
        if ($optionValidateWavFile -eq $true) {
            if ((Test-WavFile -FilePath $inputFile) -and (Test-WavStructure -FilePath $inputFile -FileExtension $_.Extension)) {
                Write-Host "File $($_.Name) already meets WAV Trigger requirements."
                $inputFileValidWAV = $true
                $conversionSkippedCount++
            } else {
                Write-Host "WAV file $($_.Name) does not meet requirements. Will be converted."
            }
        } else {
            Write-Host "Skipping validation of WAV file: $($_.Name)"
            $inputFileValidWAV = $true
            $conversionSkippedCount++
        }
    }
    
    # If the input file is a valid WAV file, we can copy it to the output folder instead of converting
    if ($inputFileValidWAV) {
        Write-Host "Copying valid WAV file: $($_.Name)"
        Copy-Item -Path $inputFile -Destination $outputFile
        $convertedCount++
        Remove-Item -Path $inputFile
    } else {

        Write-Debug "Input file properties:"
        Write-AudioFileProperties -FilePath $inputFile

        # Get sanitized metadata only if we're going to use it later
        if ($optionSanitizeMetadata) {
            $metadataString = Get-SanitizedMetadata -InputFile $inputFile
            Write-Debug "Sanitized metadata: $metadataString"
        } else {
            Write-Debug "Sanitized metadata not requested"
        }

        # FFMPEG supports a wide range of audio formats, so we'll use it as the default
        if ($optionDefaultConversionSoftware -eq "ffmpeg") {

            # The optional -hide_banner command suppresses the ffmpeg banner, though it could be useful for debugging
            if ($optionDisplayFfmpegConfigHeader) {
                $ffmpegConfigHeader = ""
            } else {
                $ffmpegConfigHeader = "-hide_banner"
            }

            # The optional -map_metadata -1 flag strips all metadata and $metdataString replaces it with our sanitized version
            if ($optionSanitizeMetadata) {
                $metadataOptions = "-map_metadata -1 $metadataString"
            } else {
                $metadataOptions = ""
            }

            # I added an intermediary file format because I thought Audacity was silently failing to convert the file to WAV due to a filename conflict
            # I was wrong, but I'm keeping the intermediary file format option for now
            # In the future, I can proably just copy Audacity's output file to the output folder and overwrite the working file
            if ($optionIntermediaryFileFormat -eq "FLAC") {
                $targetCodec = "flac"
            } elseif ($optionIntermediaryFileFormat -eq "WAV") {
                $targetCodec = "pcm_s16le"
            } elseif ($optionIntermediaryFileFormat -eq "MP3") {
                $targetCodec = "libmp3lame"
            } elseif ($optionIntermediaryFileFormat -eq "AAC") {
                $targetCodec = "aac"
            } else {
                Write-Host "Invalid intermediary file format selection. $optionIntermediaryFileFormat is not supported. Exiting." -ForegroundColor Red
                exit
            }

            # Now we build the conversion command
            $conversionCommand = "ffmpeg -i `"$inputFile`" $ffmpegConfigHeader -ac 2 -ar 44100 -acodec $targetCodec $metadataOptions `"$outputFile`""

        } elseif ($optionDefaultConversionSoftware -eq "sox") {
            # SOX typically only supports WAV file inputs, so we'll use it as a fallback
            $conversionCommand = "sox -v 0 `"$inputFile`" -c 2 -r 44100 -b 16 -t wav -e signed-integer `"$outputFile`""

        } elseif ($optionDefaultConversionSoftware -eq "audacity") {
            # Audacity does not support command line options, so we'll need to build a macro and run it
            # THIS IS NOT WORKING YET.
            $conversionCommand = 'Start-Process "C:\Path\To\nircmd.exe" -ArgumentList "sendkeypress ctrl+shift+m"'

        } else {
            Write-Host "Invalid conversion software selection. $optionDefaultConversionSoftware is not supported. Exiting." -ForegroundColor Red
            exit
        }
        
        # This is where the conversion command is executed. 
        # It's built to support multiple conversion software options, provided they all support command line options
        Write-Debug "Conversion command: $conversionCommand"
        Invoke-Expression $conversionCommand
        
        if ($?) {   # The $? variable is a boolean that returns true if the last command was successful
            Write-Debug "Conversion command completed successfully"

            # Confirm that the file was created
            if (Test-Path $outputFile) {
                Write-Debug "Successfully created audio file: $outputFile" 

                Write-Debug "`nAudio file properties after initial conversion:"
                Write-AudioFileProperties -FilePath $outputFile
                
                # Write-Host "Post-processing to improve audio file compatibility."
                # For some yet-to-be-determined reason, the file created by ffmpeg is not playable in the WAV Trigger
                # I have tried to work around this issue by doing some quick post-processing.
                # This is not an ideal solution, but it works for now
            
                if ($optionDefaultPostProcessingSoftware -eq "sox") {
                    # This did not work to resolve the issue of the file not being playable in WAV Trigger

                    # Create a temporary file for post-processing
                    $tempFile = Join-Path $outputFolder ("temp_" + $_.BaseName + ".$($optionIntermediaryFileFormat.ToLower())")
                    $postProcessingCommand = "sox -v 0 `"$outputFile`" -c 2 -r 44100 -b 16 -t wav -e signed-integer `"$tempFile`""
                    Write-Debug "Sox command: $postProcessingCommand"
                    Invoke-Expression $postProcessingCommand
                    if (Test-Path $tempFile) {
                        Write-Host "Post-processed file exists: $tempFile"
                        Move-Item -Path $tempFile -Destination $outputFile -Force
                    } else {
                        Write-Host "Post-processed file does not exist: $tempFile" -ForegroundColor Red
                    }

                } elseif ($optionDefaultPostProcessingSoftware -eq "audacity") {
                    # This is the only post-processing option that is known to work
                    # If Audacity had more command line options, we could use that from the start
                    # Doing the main conversion with another program provides control over the output file properties
                    # Exporting the file from Audacity as a WAV file provides a file that is playable in WAV Trigger
                    
                    Write-Host "`nOpening file in Audacity. Please execute the AutoWAVMaker macro manually and close Audacity when done." -ForegroundColor Yellow
                    Write-Host "  The keystrokes to execute the macro are:" -ForegroundColor Yellow
                    Write-Host "    alt-o (Tools), then a (Apply Macro), then down-arrow once (to select the AutoWAVMaker macro), then enter" -ForegroundColor Yellow
                    Write-Host "  Once the macro has been executed, close Audacity" -ForegroundColor Yellow
                    Write-Host "    Keystrokes: alt-F4, then 'n' for no save)" -ForegroundColor Yellow
                    Start-Process -FilePath $audacityLocation -ArgumentList "`"$(Resolve-Path $outputFile)`"" -Wait
                    Write-Debug "Audacity process completed"
                    $audacityOutputFile = Join-Path $env:USERPROFILE $optionAudacityMacroOutputFolder "$($_.BaseName).wav"
                    Write-Debug "Audacity output file best guess: $audacityOutputFile"
                    if (Test-Path $audacityOutputFile) {
                        Write-Debug "Audacity output file exists: $audacityOutputFile"
                        Write-Debug "Moving file to working output folder"
                        Move-Item -Path $audacityOutputFile -Destination $outputFolder -Force
                        Write-Debug "Removing original output file"
                        Remove-Item -Path $outputFile
                        $outputFile = $outputFile -replace "\.flac$", ".wav"
                    } else {
                        Write-Debug "Audacity output file does not exist: $audacityOutputFile" -ForegroundColor Red
                    }
                }

                # This is a sanity check to ensure that I've kept track of the path to the output file
                if (Test-Path $outputFile) {
                    Write-Debug "Output file still exists: $outputFile"
                } else {
                    Write-Debug "Output file does not exist: $outputFile" -ForegroundColor Red
                }

                Write-Debug "`nPost-processing audio file properties:"
                Write-AudioFileProperties -FilePath $outputFile
                
                # Validate both the audio properties and file structure
                # Validation was added while attempting to work around the issue of the file not being playable in WAV Trigger
                # The validation tests are not yet able to discern between a file that is playable and one that is not playable
                if ((Test-WavFile -FilePath $outputFile) -and (Test-WavStructure -FilePath $outputFile -FileExtension $_.Extension)) {
                    Write-Host "Successfully converted and validated $($_.Name)" -ForegroundColor Green
                    $convertedCount++
                    Remove-Item -Path $inputFile
                    } else {
                        Write-Host "WAV file validation failed for $($_.Name). The file may not meet WAV Trigger requirements." -ForegroundColor Red
                        Remove-Item -Path $outputFile
                    }
            } else {
                Write-Host "Failed to create audio file: $outputFile" -ForegroundColor Red
            }
        } else {
            Write-Host "Conversion failed for $($_.Name)" -ForegroundColor Red
        }
    }
} # End of processing audio files

# Check if any files were converted
if (($convertedCount -eq 0) -and ($conversionSkippedCount -eq 0)) {
    Write-Host "`nNo files were converted." -ForegroundColor Yellow
} else {
    if ($convertedCount > 0) {
        Write-Host "`n$convertedCount files were converted to WAV format." -ForegroundColor Green   
    }
    if ($conversionSkippedCount > 0) {
        Write-Host "`n$conversionSkippedCount WAV files were passed as-is." -ForegroundColor Yellow
    }
}

# Get the list of WAV files in the output folder
$wavFiles = Get-ChildItem -Path $outputFolder -Filter *.wav
if ($wavFiles.Count -eq 0) {
    Write-Host "`nNo audio files found in the output folder." -ForegroundColor Yellow
    Write-Host "Please check the input folder for valid files and try again."
    exit
} else {
    Write-Host "`nResulting WAV files in the output folder:"
    foreach ($file in $wavFiles) {
        Write-Host " ", $file.Name -ForegroundColor Blue
    }
} 

Write-Host "`nMoving and renaming files to the target folder..." -ForegroundColor Green

# Move WAV files to the target folder using a 3-digit prefix within the correct range of prefixes
# We have a defined prefix range, so we need to find the next available prefix in the target folder for each file

# We will use the prefix index to find the next available prefix in the target folder
$prefixIndex = 0    
# Starting at the first prefix in the range, we will step through each prefix looking for available space
# In this manner, we will fill in any gaps in the file numbering as files are converted and moved
Get-ChildItem -Path $outputFolder -Filter *.wav | ForEach-Object {
    # Each time we move to the next file, the prefix index picks up where it left off
    $wavFile = $_.FullName
    $prefix = $prefixRange[$prefixIndex]
    $targetName = "{0:D3}_{1}" -f $prefix, $_.Name
    Write-Debug "Starting target name: $targetName"
    $targetPath = Join-Path $targetFolder $targetName

    # Check for duplicate files by name (ignoring prefix)
    if ($optionCheckForDuplicateFiles) {
        $duplicateCheck = Test-DuplicateFile -TargetFolder $targetFolder -FileName $targetName
        if ($duplicateCheck.HasConflict) {
            Write-Host "Warning: A file with the same name already exists in the target folder:" -ForegroundColor Yellow
            Write-Host "  Existing file: $($duplicateCheck.ConflictingName)"
            Write-Host "  New file: $($_.Name)"
            $confirmation = Read-Host "Do you want to delete the existing file so it can be replaced with the new one? (y/n)"
            if ($confirmation -eq 'y') {
                Remove-Item -Path $duplicateCheck.ConflictingFile
                Write-Host "Deleted existing file: $($duplicateCheck.ConflictingName)"
            } else {
                Write-Host "A file with this title already exists in the target folder. Since it was not deleted,"
                Write-Host "a second instance of this title will be created with the next available prefix."
            }
        } else {
            Write-Debug "No duplicate files found for $($_.Name)"
        }
    }

    # Look for the next available prefix in the target folder
    while (Test-Path (Join-Path $targetFolder "$($prefix.ToString('D3'))*.wav")) {
        $prefixIndex++
        if ($prefixIndex -ge $prefixRange.Count) {
            Write-Host "No more available prefixes in the selected range. Exiting." -ForegroundColor Red
            Write-Host "We were targeting the scope of $($prefixRange[0]..$prefixRange[-1]), so maybe free up some space in the target range and try again."
            exit
        }
        $prefix = $prefixRange[$prefixIndex]
        $targetName = "{0:D3}_{1}" -f $prefix, $_.Name
        Write-Debug "Trying target name: $targetName"
        $targetPath = Join-Path $targetFolder $targetName
    }

    # We have our target name, so we can move and rename the file
    Write-Host "Working Name: $($_.Name)"
    Write-Host "Target Name: $targetName"
    if ($optionConfirmFileMoveAndRename) {
        $confirmation = Read-Host "Do you want to move and rename this file? (y/n)"
        if ($confirmation -eq 'y') {
            Move-Item -Path $wavFile -Destination $targetPath
            $prefixIndex++
        } else {
                Write-Host "Skipping file: $($_.Name)"
            }
    } else {
        Move-Item -Path $wavFile -Destination $targetPath
        $prefixIndex++
    }
} # End of moving and renaming files

Write-Host "`nAll files have been processed as directed." -ForegroundColor Green
Write-Host "Please check the target folder for the newly renamed and organized files."
Write-Host "Thank you for using the WAV Maker script!"
