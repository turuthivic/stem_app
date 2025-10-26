# Stem App - Backlog & Tasks

## 🎉 COMPLETED (Session 1)

### Core Functionality
- ✅ Rails 8 app with PostgreSQL, Tailwind CSS, Hotwire (Turbo/Stimulus)
- ✅ Audio file upload with Active Storage (drag-drop + file picker)
- ✅ AudioFile and SeparationJob models with status tracking
- ✅ Background job processing with Sidekiq
- ✅ Python integration (librosa/soundfile) for audio separation
- ✅ Real-time progress tracking with Turbo Streams
- ✅ Docker support, CI/CD, test suite

### UI/UX Improvements
- ✅ Integrated Plyr audio player with professional controls
- ✅ Custom blue theme styling for Plyr (gradient, shadows, rounded corners)
- ✅ Single player with preview buttons (Original/Vocals/Music)
- ✅ Upload form moved to separate `/audio_files/new` page
- ✅ Clean homepage with audio file list
- ✅ Show page with real-time status updates via Turbo Streams
- ✅ Proper navigation flow: List → Upload → Processing → Play

### Bug Fixes
- ✅ Fixed separation_type enum (string vs integer mismatch)
- ✅ Fixed stem attachment (temp directory cleanup timing issue)
- ✅ Fixed upload validation and UX
- ✅ Fixed download buttons (Turbo bypass)
- ✅ Fixed Plyr import (loaded as global script)
- ✅ Fixed Plyr settings menu overflow

## 🎉 COMPLETED (Session 3 - 2025-10-26)

### Critical Bug Fixes - Plyr Audio Player
- ✅ **Fixed Plyr Blank Video Errors** - Eliminated all blank.mp4 loading errors
  - Removed native `controls` attribute from audio element
  - Fixed blank.mp4 placeholder by setting src before Plyr initialization
  - Fixed play button not working on subsequent track switches
  - Fixed "can't redefine non-configurable property 'quality'" error
  - Fixed play/pause loop caused by stopOtherPlayers affecting current player

### Technical Implementation
- ✅ **Optimized Track Switching** - Reuse Plyr instance instead of destroy/recreate
  - First load: Create Plyr instance with audio src pre-populated
  - Subsequent loads: Update audio element directly, bypass Plyr source API
  - Wait for native `canplay` event before auto-playing
  - Seamless, fast track switching with great UX

## 🎉 COMPLETED (Session 2 - 2025-10-24)

### Performance Optimization
- ✅ **Optimized Audio File Serving** - Changed from `send_data` to Active Storage redirects
  - Updated `AudioFilesController#send_stem` to use `redirect_to rails_blob_path()`
  - Browser now caches audio files properly
  - Supports HTTP byte-range requests for instant seeking
  - Files served directly from storage, bypassing Rails
  - Much faster playback experience

### Git Commits Created
1. Initial commit with full Rails setup
2. Fix separation_type enum to use string values
3. Fix upload validation and download functionality
4. Fix audio separation stem attachment issue
5. Add dump.rdb to .gitignore
6. Add audio preview progress bar and improved track visibility
7. Integrate Plyr audio player for professional playback controls
8. Major UI/UX improvements: Single player, styled Plyr, separate upload page
9. Fix Plyr import error by loading as global script
10. Fix Plyr settings menu overflow issue
11. Add .claude/settings.local.json to gitignore
12. Add project task tracking documentation

---

## 📋 TODO - BACKLOG

### 🎨 MEDIUM PRIORITY - UX Enhancements

#### Add Audio Waveform Visualization
- Consider upgrading to WaveSurfer.js for visual waveforms
- Helps users verify separation quality
- Ability to sync multiple players to compare stems at same timestamp
- Click waveform to seek

#### Batch Processing
- Allow uploading multiple files at once
- Queue system for processing
- Bulk download of separated stems

#### User Authentication & File Management
- Add Devise or similar for user accounts
- Each user manages their own audio files
- File organization (folders, tags, search)

#### Export Options
- Support multiple output formats (MP3, FLAC, OGG)
- Quality/bitrate selection
- Zip download of all stems

---

### 🔧 MEDIUM PRIORITY - Technical Improvements

#### Upgrade to Demucs ML-based Separation
**Current:** Using simple center-channel extraction (demo quality)
**Needed:** Integrate actual Demucs model for professional separation

**Files:**
- `lib/audio_processing/separate_audio.py` - Already exists but not used
- `requirements.txt` - Already has demucs>=4.0.0
- Update `AudioSeparationJob` to use Demucs script instead

**Benefits:**
- Professional-quality stem separation
- Support for 4-stem separation (vocals, drums, bass, other)
- Industry-standard results

#### Better Error Handling & Logging
- Add error tracking (Sentry, Rollbar, etc.)
- Better user-facing error messages
- Retry failed jobs with exponential backoff
- Email notifications for failed jobs

#### Progress Accuracy
- Current progress is simulated in Python script
- Use actual Demucs progress callbacks if available
- Show estimated time remaining

---

### 🐛 LOW PRIORITY - Polish & Nice-to-Haves

#### Audio Player Enhancements
- Keyboard shortcuts (space = play/pause, arrows = seek)
- Remember volume preference (localStorage)
- A/B comparison mode (play vocals+music simultaneously)
- Equalizer visualization

#### Mobile Optimization
- Touch-friendly UI improvements
- Responsive player controls
- Mobile upload from camera/mic

#### Accessibility
- Better screen reader support
- Keyboard navigation improvements
- ARIA labels for all interactive elements

#### Analytics
- Track usage metrics (uploads, downloads, play counts)
- Popular file types/sizes
- Processing time statistics

---

### 📦 FUTURE FEATURES

#### Advanced Separation Options
- Custom separation models
- Separation quality settings (fast vs. high quality)
- Isolation strength controls
- Multiple separation types per file

#### Collaboration
- Share separation results via link
- Collaborate on projects
- Comments on stems

#### API
- REST API for programmatic access
- Webhooks for job completion
- API key management

#### Integrations
- DAW plugin integration
- Cloud storage (Dropbox, Google Drive)
- Streaming service integration

---

## 🏗️ TECHNICAL DEBT

### Code Quality
- Add more comprehensive tests
- Improve test coverage for edge cases
- Add integration tests for Python script
- RuboCop violations to fix

### Documentation
- API documentation
- Developer setup guide improvements
- Deployment guide
- User guide/help section

### Infrastructure
- Set up staging environment
- Add monitoring (New Relic, etc.)
- CDN for static assets
- Database backups strategy

---

## 📝 NOTES

### Current Architecture
- **Rails 8** with PostgreSQL
- **Sidekiq** for background jobs
- **Active Storage** for file management
- **Python** (librosa/soundfile) for audio processing
- **Plyr** for audio playback
- **Tailwind CSS** for styling
- **Hotwire** (Turbo + Stimulus) for interactivity

### Key Files
- Models: `app/models/audio_file.rb`, `app/models/separation_job.rb`
- Jobs: `app/jobs/audio_separation_job.rb`
- Python: `lib/audio_processing/simple_separate.py`, `lib/audio_processing/separate_audio.py`
- Controllers: `app/controllers/audio_files_controller.rb`
- Views: `app/views/audio_files/`
- Stimulus: `app/javascript/controllers/audio_player_controller.js`

### Known Issues
- Python script uses basic center-channel extraction (not production quality)
- No user authentication
- No file size limits enforced at storage level

### Environment Setup
- Ruby 3.3+
- Python 3.10+
- PostgreSQL 14+
- Redis (for Sidekiq)
- FFmpeg (for audio processing)

---

## 🎯 NEXT SESSION PRIORITIES

1. ✅ **Fix audio file serving** - COMPLETED! (Session 2)
2. ✅ **Fix Plyr audio player issues** - COMPLETED! (Session 3)
3. **Consider Demucs upgrade** - For production-quality separation
4. **Add user authentication** - If planning to deploy
5. **Add waveform visualization** - Consider WaveSurfer.js

---

*Last Updated: 2025-10-26*
*Session 3: Plyr Audio Player Bug Fixes Complete*
