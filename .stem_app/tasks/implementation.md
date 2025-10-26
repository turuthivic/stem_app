# Implementation Notes

## Plyr Audio Player Bug Fixes (2025-10-26)

### Problem Statement
The Plyr audio player had multiple critical issues affecting playback:
1. **Blank.mp4 errors**: Console showed errors about loading `https://cdn.plyr.io/static/blank.mp4`
2. **Play button not working**: After switching tracks, play button became unresponsive
3. **Play/pause loop**: Track would start playing then immediately pause in a loop
4. **Property redefinition errors**: `can't redefine non-configurable property "quality"`

### Root Causes Identified

#### Issue #1: Native Controls Conflict
The `<audio controls>` attribute created native browser controls that conflicted with Plyr initialization.

#### Issue #2: Empty Audio Element on Init
When Plyr initialized on an empty `<audio>` element, it loaded `blank.mp4` as a placeholder, causing decode errors.

#### Issue #3: stopOtherPlayers Stopping Current Player
The `stopOtherPlayers()` function looped through ALL players and paused them, including the one that just started playing.

#### Issue #4: Plyr Source API Triggering Blank.mp4
Using `player.source = {...}` to change tracks triggered Plyr's internal source mechanism, which loaded `blank.mp4` first.

#### Issue #5: Destroy/Recreate Creating Non-Configurable Properties
Destroying and recreating Plyr left non-configurable properties on the audio element that couldn't be redefined.

### Solutions Implemented

#### Fix #1: Remove Native Controls
**File:** `app/views/audio_files/_audio_file.html.erb:188`

**Before:**
```html
<audio id="audio_player_<%= audio_file.id %>" controls></audio>
```

**After:**
```html
<audio id="audio_player_<%= audio_file.id %>"></audio>
```

Plyr provides its own controls, so the native `controls` attribute was unnecessary and conflicting.

#### Fix #2: Set Source Before Plyr Initialization
**File:** `app/javascript/controllers/audio_player_controller.js:82-83`

```javascript
// Set the source on the raw audio element BEFORE initializing Plyr
audioElement.src = url
audioElement.type = url.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav'

player = new Plyr(audioElement, { ... })
```

By setting the audio source before creating the Plyr instance, we avoid the blank.mp4 placeholder entirely.

#### Fix #3: Exclude Current Player from stopOtherPlayers
**File:** `app/javascript/controllers/audio_player_controller.js:125-132`

**Before:**
```javascript
stopOtherPlayers() {
  this.constructor.players.forEach((player, id) => {
    if (!player.paused) {
      player.pause()
    }
  })
}
```

**After:**
```javascript
stopOtherPlayers(excludeId = null) {
  // Stop all other Plyr instances except the one with excludeId
  this.constructor.players.forEach((player, id) => {
    if (id !== excludeId && !player.paused) {
      player.pause()
    }
  })
}
```

Now when a player starts, it passes its own ID to avoid stopping itself.

#### Fix #4 & #5: Reuse Plyr Instance + Direct Audio Element Manipulation
**File:** `app/javascript/controllers/audio_player_controller.js:60-83`

**Strategy:** Instead of destroying and recreating Plyr, or using `player.source`, we:
1. **Reuse the same Plyr instance** for all track changes
2. **Update the underlying audio element directly** to bypass Plyr's source API

**Implementation:**

```javascript
if (player) {
  // Player exists - update the underlying audio element directly
  player.pause()

  // Update the underlying audio element's src directly (bypasses Plyr's source API)
  audioElement.src = url
  audioElement.type = url.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav'

  // Load the new source
  audioElement.load()

  // Play when ready
  const playWhenReady = () => {
    player.play().catch(error => {
      console.error('Error playing new track:', error)
    })
    audioElement.removeEventListener('canplay', playWhenReady)
  }

  audioElement.addEventListener('canplay', playWhenReady, { once: true })
} else {
  // First time - create new Plyr instance
  audioElement.src = url
  audioElement.type = url.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav'

  player = new Plyr(audioElement, { ... })
  // ... set up event handlers
}
```

**Why This Works:**
- Plyr UI automatically updates because it listens to the underlying audio element's events
- No destroy/recreate means no property redefinition errors
- Direct element manipulation bypasses Plyr's source API (no blank.mp4)
- Clean, fast track switching

### Technical Details

#### How Track Switching Works Now

1. **User clicks "Vocals" button**
2. **Controller checks**: Does Plyr instance exist for this audio element?
3. **If exists** (subsequent track load):
   - Pause current playback
   - Update `audioElement.src` and `audioElement.type` directly
   - Call `audioElement.load()` to reset and load new source
   - Listen for `canplay` event on audio element
   - When ready, call `player.play()` through Plyr API
4. **If doesn't exist** (first track load):
   - Set `audioElement.src` and `audioElement.type`
   - Create new Plyr instance
   - Store in static Map for reuse
   - Set up event handlers (play, error, canplay)

#### Event Flow

**First Load:**
```
Button Click → loadTrack()
  → Set audioElement.src
  → new Plyr(audioElement)
  → Plyr emits 'ready' event
  → Audio emits 'canplay' event
  → Auto-play starts
```

**Subsequent Loads:**
```
Button Click → loadTrack()
  → Pause current track
  → Update audioElement.src
  → audioElement.load()
  → Audio emits 'canplay' event
  → Auto-play starts
```

### Benefits Achieved

#### User Experience
- ✅ **Clean console**: No blank.mp4 errors
- ✅ **Reliable playback**: Play button works every time
- ✅ **Fast switching**: Instant track changes
- ✅ **Auto-play**: New tracks start automatically
- ✅ **Smooth UI**: No flashing or rebuilding of controls

#### Technical
- ✅ **Performance**: Reusing Plyr instance is more efficient
- ✅ **Maintainability**: Simpler code path (no destroy/recreate logic)
- ✅ **Compatibility**: Works with Plyr's architecture rather than against it
- ✅ **Scalability**: Static Map efficiently manages multiple players across page

### Testing Performed

#### Scenarios Tested
1. ✅ Click "Original" - plays immediately
2. ✅ Click "Vocals" - switches and plays
3. ✅ Click "Music" - switches and plays
4. ✅ Click back to "Original" - works perfectly
5. ✅ Play/pause button responsive throughout
6. ✅ Progress bar updates correctly
7. ✅ Volume controls work
8. ✅ Speed settings work

#### Console Verification
- ✅ No blank.mp4 errors
- ✅ No property redefinition errors
- ✅ No play/pause loop errors
- ✅ Clean event flow logs

### Related Files
- `app/javascript/controllers/audio_player_controller.js` - Main Stimulus controller
- `app/views/audio_files/_audio_file.html.erb:88-189` - Preview buttons and player HTML
- `app/javascript/application.js` - Plyr global script loading

### Future Enhancements

#### Possible Optimizations
- Add loading spinner during track switching
- Preload next track for instant switching
- Keyboard shortcuts (space = play/pause)
- Remember playback position when switching tracks
- Visual feedback for active track button

---

## Audio File Serving Optimization (2025-10-24)

### Problem Statement
Audio files were being served inefficiently through Rails using `send_data attachment.download`:
- Downloaded entire file into Rails memory on every play/seek
- No browser caching
- No HTTP byte-range support (seeking required full re-download)
- High memory usage and slow performance

### Solution Implemented
Changed `AudioFilesController#send_stem` to redirect to Active Storage URLs instead of streaming through Rails.

#### Code Changes

**File:** `app/controllers/audio_files_controller.rb`

**Before:**
```ruby
def send_stem(attachment)
  if attachment.attached?
    send_data attachment.download,
              type: attachment.content_type,
              disposition: 'inline'
  else
    head :not_found
  end
end
```

**After:**
```ruby
def send_stem(attachment)
  if attachment.attached?
    # Redirect to Active Storage URL for better performance:
    # - Enables browser caching
    # - Supports HTTP byte-range requests (instant seeking)
    # - Serves directly from storage (bypasses Rails)
    redirect_to rails_blob_path(attachment, disposition: "inline"), allow_other_host: true
  else
    head :not_found
  end
end
```

### Technical Details

#### How It Works
1. Client requests `/audio_files/:id/stems?stem_type=vocals`
2. Rails responds with `302 Found` redirect to `/rails/active_storage/disk/:encoded_key/vocals.wav`
3. `ActiveStorage::DiskController` serves the file directly from disk
4. Response includes proper HTTP headers:
   - `Cache-Control` for browser caching
   - `ETag` for conditional requests
   - `Accept-Ranges: bytes` for byte-range support
   - `Content-Type: audio/wav`

#### Active Storage Routes
Rails automatically provides these routes (verified via `bin/rails routes`):
- `rails_service_blob` → `/rails/active_storage/blobs/redirect/:signed_id/*filename`
- `rails_disk_service` → `/rails/active_storage/disk/:encoded_key/*filename`

#### Configuration
- **Storage:** Using `:local` disk service (config/storage.yml)
- **Location:** Files stored in `storage/` directory
- **Environment:** development.rb sets `config.active_storage.service = :local`

### Benefits Achieved

#### Performance
- **Memory:** No longer loads entire audio files into Rails process memory
- **Speed:** Direct disk serving is much faster than Rails streaming
- **Caching:** Browser caches audio files, subsequent plays load instantly

#### User Experience
- **Instant Seeking:** HTTP byte-range requests allow jumping to any timestamp without re-downloading
- **Faster Loading:** Cached files load from browser cache
- **Better Reliability:** No Rails memory issues with large files

#### Scalability
- **Production Ready:** Works with S3, GCS, Azure when configured
- **CDN Compatible:** Can add CloudFront/CloudFlare in front of Active Storage URLs
- **Resource Efficient:** Rails processes freed from file serving duty

### Testing Recommendations

#### Browser DevTools (Network Tab)
1. Upload and process an audio file
2. Click "Original" or "Vocals" preview button
3. Check Network tab for:
   - `302` redirect from `/stems?stem_type=vocals`
   - `200` response from `/rails/active_storage/disk/...`
   - Response headers include `Cache-Control`, `ETag`, `Accept-Ranges`
4. Seek in the player:
   - Should see `206 Partial Content` responses
   - Only requested byte ranges transferred
5. Reload page and play same track:
   - Should see `304 Not Modified` (cached)

#### Performance Comparison
**Before:**
- Every play/seek: Full file download through Rails
- Memory: ~50MB per concurrent playback (for typical song)
- Seeking: Slow, requires full re-download

**After:**
- First play: Redirect + direct file serve + cache
- Subsequent plays: Load from cache (instant)
- Seeking: Byte-range requests (instant)
- Memory: Minimal Rails overhead

### Future Enhancements

#### Production Deployment
When deploying to production:
1. Switch to cloud storage (S3, GCS, Azure)
2. Update `config/storage.yml` with credentials
3. Set `config.active_storage.service = :amazon` in production.rb
4. Consider CDN for even faster global delivery

#### Optimization Ideas
- Add `max-age` cache headers for longer browser caching
- Implement signed URLs with expiration for security
- Add CORS headers if serving from different domain
- Consider video variant generation for different bitrates/formats

### Related Files
- `app/controllers/audio_files_controller.rb:98-108` - Implementation
- `app/views/audio_files/_audio_file.html.erb:89-122` - Preview button URLs
- `app/javascript/controllers/audio_player_controller.js:17-46` - Plyr player loading
- `config/storage.yml` - Active Storage configuration
- `config/environments/development.rb:32` - Environment config

---

*Last Updated: 2025-10-26*
