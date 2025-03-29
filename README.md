# WAV Trigger Audio File Processor

A PowerShell script that automates the conversion of MP3 and M4A files to WAV format specifically for WAV Trigger boards. This tool ensures all output files meet the strict WAV Trigger requirements and handles file organization according to specifications.

## Project Context
This tool is part of a larger project to add digital sound to a 1947 Chicago Coin Play Boy pinball machine. The system uses a WAV Trigger board to manage audio playback for various game events, including music, sound effects, and voice announcements. See [CONFIGURATION.md](CONFIGURATION.md) for detailed information about the WAV Trigger setup and project vision.

## Features

- Converts MP3 and M4A files to WAV format meeting WAV Trigger requirements:
  - 16-bit PCM encoding
  - 44.1 kHz sample rate
  - Stereo output
  - Uncompressed PCM format
- Automatically validates converted WAV files
- Handles file renaming and organization
- Supports both primary (101-199) and alternate (201-299) track collections
- Preserves essential metadata during conversion
- Interactive file processing with user confirmation

## Prerequisites

- Windows PowerShell 7 or later
- [ffmpeg](https://ffmpeg.org/) installed via Chocolatey (recommended)
- Source audio files in MP3 or M4A format

## Installation

1. Clone this repository or download the script
2. Ensure ffmpeg is installed:
   ```powershell
   choco install ffmpeg
   ```

## Usage

1. Place your MP3 or M4A files in the `Source_Files` folder
2. Run the script:
   ```powershell
   .\wavmaker.ps1
   ```
3. Follow the interactive prompts to:
   - Confirm file renames
   - Select track collection type (primary/alternate)
   - Confirm file moves and renames

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