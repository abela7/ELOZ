# Alarm Sound Assets

This folder needs to contain alarm sound files for the special task alarm feature.

## Required File

Add an `alarm.mp3` file to this folder. This will be used as the alarm sound when:
- Special task reminders fire with Alarm Mode enabled
- The app is killed/closed (background alarm)

## Recommended Sources

1. **Free alarm sounds:** https://freesound.org/search/?q=alarm
2. **Android system sounds:** You can copy a sound from your device:
   - Path: `/system/media/audio/alarms/`

## Technical Requirements

- Format: MP3 or WAV
- Recommended length: 3-10 seconds
- The alarm package will loop the sound until dismissed

## Alternative

If no `alarm.mp3` is provided, the alarm will still fire but may not have audio.
The app will fall back to the system notification if the audio file is missing.
