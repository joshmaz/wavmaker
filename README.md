# WAV Maker

A PowerShell script for converting and organizing audio files to meet WAV Trigger requirements.

## Workflow

The script follows a two-step process to prepare audio files for use with the WAV Trigger board:

1. Initial Processing with FFmpeg
   - Source files (MP3, M4A, or WAV) are processed using FFmpeg
   - Files are standardized to meet basic WAV Trigger requirements:
     - 16-bit PCM format
     - 44.1 kHz sample rate
     - Stereo output
     - Uncompressed PCM encoding
   - This creates an intermediate WAV file with consistent properties

2. Audacity Processing and Normalization
   - The standardized WAV file is then processed through Audacity
   - An automated macro applies:
     - Normalization to ensure consistent volume levels
     - Any required audio cleanup
     - Final format validation
   - The result is a playable WAV file fully compatible with the WAV Trigger board

This two-stage workflow ensures that files from any source are properly formatted, normalized, and ready for use, while preserving audio quality throughout the conversion process.

This script has evolved through several iterations to find the optimal workflow for my needs. While the current default process uses FFmpeg and Audacity, the script includes other processing options that can be enabled through configuration variables:

- Direct FFmpeg processing without Audacity
- Sox audio processing capabilities 
- VLC media conversion
- Direct WAV metadata manipulation
- Various file organization strategies

The two-stage FFmpeg/Audacity workflow was chosen as the default because it provides:

- Consistent results across different source formats
- Reliable normalization through Audacity's processing
- Preservation of audio quality
- Automated operation through Audacity macros

However, the script remains flexible - other processing paths can be enabled by adjusting variables in the configuration section. This allows the workflow to be customized based on available tools and specific requirements.

## Features

- Converts MP3 and M4A files to WAV format
- Creates an Audicty macro to automate as much as possible
- Sanitizes metadata to ensure compatibility
- Handles file organization and naming:
  - Removes leading track numbers from source files
  - Assigns 3-digit prefixes supporting multiple WAV Trigger file scopes
  - Prevents duplicate files with different numerical prefixes

## Requirements

- PowerShell 7 or later
- FFmpeg installed in the path
- Audactity installed in a common location
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

- Primary tracks: `101_` to `199_`
- Alternate tracks: `201_` to `299_`
- Example: `101_SongName.wav`

## Requirements

See [requirements.md](requirements.md) for detailed WAV Trigger file specifications.

## Version History

See [CHANGELOG.md](CHANGELOG.md) for version history and updates. 