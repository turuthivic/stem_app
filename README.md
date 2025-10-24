# Stem Separation App

A Rails 8 application for separating audio files into individual stems (vocals, accompaniment, drums, etc.) using Python-based audio processing.

## Features

- **Audio Upload**: Drag-and-drop or file picker interface for audio files (MP3, WAV, FLAC, M4A)
- **Stem Separation**: Separate audio into vocals and accompaniment using signal processing
- **Real-time Progress Tracking**: Live updates via Turbo Streams during separation
- **Background Processing**: Sidekiq-powered async job processing
- **Audio Playback**: Built-in audio player for original and separated stems
- **Multiple Separation Types**: Support for vocals/accompaniment, drums, bass, and piano separation

## Tech Stack

- **Rails**: 8.0.3
- **Database**: PostgreSQL
- **CSS**: Tailwind CSS
- **JavaScript**: Stimulus controllers with Hotwire (Turbo/Stimulus)
- **Background Jobs**: Sidekiq
- **File Storage**: Active Storage
- **Python**: librosa, soundfile, demucs for audio processing

## System Requirements

- Ruby 3.3+
- Python 3.10+
- PostgreSQL 14+
- Redis (for Sidekiq)
- FFmpeg (for audio processing)

## Installation

1. Install dependencies:
```bash
bundle install
pip3 install -r requirements.txt
```

2. Setup database:
```bash
rails db:create db:migrate
```

3. Start services:
```bash
bin/dev
```

This starts:
- Rails server (Puma)
- Tailwind CSS watcher
- Sidekiq worker

## Usage

1. Navigate to `http://localhost:3000`
2. Upload an audio file via drag-and-drop or file picker
3. Watch real-time progress as the file is processed
4. Download or play the separated stems

## Architecture

### Models
- **AudioFile**: Stores audio file metadata and attachments (original, vocals, accompaniment)
- **SeparationJob**: Tracks separation job progress and status

### Background Jobs
- **AudioSeparationJob**: Handles async audio separation using Python scripts

### Python Processing
- `lib/audio_processing/simple_separate.py`: Basic center-channel extraction for demo purposes
- `lib/audio_processing/separate_audio.py`: Advanced ML-based separation using Demucs (future)

### Stimulus Controllers
- **audio_player_controller**: Audio playback controls
- **drag_drop_controller**: Drag-and-drop file upload
- **upload_controller**: File upload handling
- **flash_controller**: Auto-dismissing flash messages

## Testing

```bash
rails test
rails test:system
```

## Docker

Build and run with Docker:
```bash
docker build -t stem-app .
docker run -p 3000:3000 stem-app
```

## Future Enhancements

- Implement full Demucs ML-based separation
- Support for 4-stem separation (vocals, drums, bass, other)
- Batch processing of multiple files
- User authentication and file management
- Export in multiple formats
- Audio preview before downloading
