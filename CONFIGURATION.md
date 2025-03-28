# WAV Trigger Configuration Guide

## Project Overview
This configuration is designed for a 1947 Chicago Coin Play Boy pinball machine, featuring an authentic 1940s big-band jazz theme. The system uses a WAV Trigger board to manage audio playback for various game events, including music, sound effects, and voice announcements.

## Hardware Configuration

### Physical Switch Mapping (16 available)
1. **On-board test button** - Always track 001
2. **New game (Reset bar)** - Random music track
3. **New game alternate*** - Random alternate track
4. **Kickout holes** - Play random kickout track
5. **Kickout holes alternate***
6. **Rollovers** - Play random rollover track
7. **Rollovers alternate***
8. **Tilt relay** - Play random tilt track, non-polyphonic
9. **Tilt relay alternate***, non-polyphonic
10. **Information button** - Play informational voice track
11. **Quiet button** - Stop music tracks
12. **1K score relay**
13. **10K score relay**
14-16. **Undefined**

### Special Hardware Considerations
- Three-position DPDT for bell settings:
  - Mechanical bell on
  - No bell (off)
  - Digital bell on
- Optocoupler for game timer status monitoring
- Game state optocoupler:
  - Power up sound (normal state)
  - Power down sound (inverted state)

### Switch Configuration Notes
- Primary/Alternate toggles use 2PDT switches
- New game triggers (pri/alt) are non-polyphonic
- Tilt triggers (pri/alt) are non-polyphonic
- Quiet button includes informational tracks

## Audio File Organization

### File Number Ranges
- **001**: Self-test / welcome track
- **009**: Information track
- **011**: Score wheel, small
- **012**: Score wheel, large
- **020-029**: Kickout hole sounds (Primary)
- **030-039**: Kickout hole sounds (Alternate)
- **040-049**: Rollover lane sounds (Primary)
- **050-059**: Rollover lane sounds (Alternate)
- **060-069**: Tilt relay sounds (Primary)
- **070-079**: Tilt relay sounds (Alternate)
- **100-199**: Music tracks (Primary)
- **200-299**: Music tracks (Alternate)
- **001-018**: Sample files (for troubleshooting undefined triggers)

## WAV Trigger Configuration File
```ini
#VOLM -15
#TRIG 01, 1, 0, 1, 1, 0, 4, -7, 101, 111
#TRIG 02, 1, 0, 1, 1, 0, 2, -7, 201, 209
#TRIG 03, 1, 0, 1, 1, 1, 4, 0, 21, 27
#TRIG 04, 1, 0, 1, 1, 1, 4, 0, 31, 34
#TRIG 05, 1, 0, 1, 1, 1, 4, 0, 41, 44
#TRIG 06, 1, 0, 1, 1, 1, 4, 0, 51, 53
#TRIG 07, 1, 0, 1, 1, 0, 4, 0, 61, 66
#TRIG 08, 1, 0, 1, 1, 0, 4, 0, 71, 73
#TRIG 09, 1, 0, 1, 0, 1, 1, 0, ,
#TRIG 10, 1, 1, 1, 0, 0, 7, 0, 100, 299
#TRIG 11, 1, 0, 1, 1, 1, 1, 0, ,
#TRIG 12, 1, 0, 1, 1, 1, 1, 0, ,
```

### Configuration Parameters
Each TRIG line contains the following parameters:
1. Trigger number
2. Enable/disable
3. Polyphonic setting
4. Loop setting
5. Stop on next trigger
6. Stop on next loop
7. Volume adjustment
8. Start file number
9. End file number

## Development Tools
The project includes a PowerShell script (`wavmaker.ps1`) that handles:
- WAV file conversion to meet WAV Trigger requirements
- Metadata sanitization
- File organization and naming
- Gap-filling in the target directory
- Duplicate prevention

## Future Considerations
- Sample sound removal from final product
- Additional trigger mapping for undefined inputs
- Volume level optimization
- Sound effect library expansion
- Music track rotation management 