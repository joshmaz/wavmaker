# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9] - 2025-03-28
### Changed
- Improved ffmpeg detection to use system PATH instead of hardcoded path
- Removed hardcoded ffmpeg path variable for better flexibility

## [1.8] - 2025-03-28
### Added
- Support for processing WAV files in source folder
- Automatic validation of WAV files against WAV Trigger requirements
- Direct copying of valid WAV files without conversion
- Conversion of invalid WAV files to meet requirements

### Changed
- Updated documentation to reflect WAV file handling capabilities
- Improved file processing logic to handle multiple input formats
- Added WAV to file extensions being processed for prefix removal

## [1.7] - 2025-03-28
### Changed
- Reverted metadata field names to original format (title, artist, album, date)
- Improved duplicate detection to prevent files with same name but different prefixes
- Updated warning message to show original filename without prefix

## [1.6] - 2024-03-28
### Changed
- Improved metadata sanitization:
  - Now strips ALL metadata before adding sanitized fields
  - Removes special characters from text fields
  - Keeps only numbers in date fields
  - Trims whitespace from all fields

## [1.5] - 2024-03-28
### Changed
- Renamed `MP3s` folder to `Source_Files` for better clarity and to reflect support for multiple input formats

## [1.4] - 2024-03-28
### Added
- Metadata sanitization during conversion
  - Keeps only essential metadata (title, artist, album, date)
  - Removes inappropriate or unnecessary metadata
  - Falls back to sensible defaults if metadata is missing

## [1.3] - 2024-01-08
### Added
- WAV file validation to ensure compliance with WAV Trigger requirements
- Support for M4A input files
- Improved error handling and user feedback
- Updated ffmpeg command to enforce specific WAV requirements:
  - 16-bit PCM encoding
  - 44.1 kHz sample rate
  - Stereo output
  - Uncompressed PCM format

### Changed
- Updated file naming convention to use hyphen separator (e.g., `101-SongName.wav`)
- Improved documentation and code comments
- Enhanced error messages and user feedback

## [1.2] - 2024-01-08
### Added
- Stereo output support to ffmpeg command to meet WAVTrigger board requirements

## [1.1] - 2024-01-08
### Added
- Better file handling after processing
- Support for `.m4a` along with `.mp3` source files

## [1.0] - 2024-01-08
### Added
- Initial release
- Basic MP3 to WAV conversion functionality
- File renaming and organization features 