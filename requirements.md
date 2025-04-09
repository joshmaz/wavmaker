# WAV Trigger Audio File Requirements

## File Format Requirements
- **Format:** WAV (uncompressed PCM)
- **Bit Depth:** 16-bit
- **Channels:** Stereo only (even if source is mono)
- **Sample Rate:** 44.1 kHz (CD quality)
- **Encoding:** Linear PCM (not µ-law, A-law, or any compressed variant)

> **Important:** Mono files or files with sample rates other than 44.1 kHz will not play or may cause unpredictable behavior.

## microSD Card Requirements
- **File System:** FAT16 or FAT32
- **Allocation size:** 32kB (best performance)
- **Card type:** Class 10 or better recommended
- Place all files in the root directory of the card

## Audio Conversion Process
### Using Audacity
1. Import your MP3 file
   - `File > Import > Audio...`

2. Convert to Stereo (if mono)
   - If mono: `Tracks > Mix > Mix and Render to Stereo`

3. Set project rate to 44,100 Hz
   - Look at the bottom left of the window

4. Export as WAV
   - `File > Export > Export as WAV`
   - Format: WAV (Microsoft) signed 16-bit PCM
   - Ensure "Stereo" is selected

5. Rename file with proper numeric prefix
   - Example: `007_Cowbell.wav` for Trigger 7
