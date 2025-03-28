# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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