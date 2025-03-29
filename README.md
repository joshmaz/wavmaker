# WAV Maker

A PowerShell script for converting and organizing audio files to meet WAV Trigger requirements.

## Features

- Converts MP3 and M4A files to WAV format
- Processes existing WAV files:
  - Validates against WAV Trigger requirements
  - Copies valid files without modification
  - Converts invalid files to meet requirements
- Sanitizes metadata to ensure compatibility
- Handles file organization and naming:
  - Removes leading track numbers from source files
  - Assigns 3-digit prefixes for primary (101-199) or alternate (201-299) collections
  - Prevents duplicate files with different numerical prefixes

## Requirements

- PowerShell 7 or later
- FFmpeg installed in the path
- Source audio files in MP3, M4A, or WAV format

## Usage

1. Place your source files in the `Source_Files` folder
2. Run the script: `.\wavmaker.ps1`
3. Follow the prompts to:
   - Remove leading track numbers from source files
   - Process and validate audio files
   - Select primary or alternate track collection
   - Move files to the target folder with appropriate prefixes

## Output

The script will:

1. Convert or validate files to meet WAV Trigger requirements:
   - 16-bit PCM
   - 44.1 kHz sample rate
   - Stereo output
   - Uncompressed PCM encoding
2. Organize files in the target folder with 3-digit prefixes
3. Preserve valid WAV files without modification
4. Convert invalid files to meet requirements

## Notes

- Valid WAV files are copied without metadata modification
- Invalid WAV files are converted to meet requirements
- Source files are removed after successful processing
- Duplicate files are prevented in the target folder

## Project Context

This tool is part of a larger project to add digital sound to a 1947 Chicago Coin Play Boy pinball machine. The system uses a WAV Trigger board to manage audio playback for various game events, including music, sound effects, and voice announcements. See [CONFIGURATION.md](CONFIGURATION.md) for detailed information about the WAV Trigger setup and project vision.

## Installation

1. Clone this repository or download the script
2. Ensure ffmpeg is installed:

   ```powershell
   choco install ffmpeg
   ```

## File Organization

- Source files: Place in `Source_Files` folder
- Converted files: Temporarily stored in `WAVs` folder
- Final destination: Files are moved to the configured target folder with proper 3-digit prefixes

## File Naming Convention

- Primary tracks: `101-` to `199-`
- Alternate tracks: `201-` to `299-`
- Example: `101-SongName.wav`

## Requirements

See [requirements.md](requirements.md) for detailed WAV Trigger file specifications.

## Version History

See [CHANGELOG.md](CHANGELOG.md) for version history and updates. 