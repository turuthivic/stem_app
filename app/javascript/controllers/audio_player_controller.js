import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurfer.js"

export default class extends Controller {
  static values = {
    playerContainer: String
  }

  // Store WaveSurfer instances globally to share across button instances
  static wavesurfers = new Map()

  // Expose globally for waveform_player_controller
  static {
    window.audioPlayerWavesurfers = this.wavesurfers

    // Handle window resize and orientation change for waveform redraw
    let resizeTimeout
    const handleResize = () => {
      clearTimeout(resizeTimeout)
      resizeTimeout = setTimeout(() => {
        window.audioPlayerWavesurfers.forEach((ws) => {
          if (ws && typeof ws.setOptions === 'function') {
            // Trigger a redraw by getting current width
            const container = ws.getWrapper()?.parentElement
            if (container) {
              ws.setOptions({ height: 80 })
            }
          }
        })
      }, 150)
    }

    window.addEventListener('resize', handleResize)
    window.addEventListener('orientationchange', handleResize)
  }

  // Stem color mapping
  static stemColors = {
    original: { waveColor: '#9ca3af', progressColor: '#4b5563' },
    vocals: { waveColor: '#c084fc', progressColor: '#a855f7' },
    drums: { waveColor: '#fdba74', progressColor: '#f97316' },
    bass: { waveColor: '#93c5fd', progressColor: '#3b82f6' },
    other: { waveColor: '#6ee7b7', progressColor: '#10b981' }
  }

  connect() {
    // Each button gets its own controller instance
  }

  disconnect() {
    // Don't destroy player on button disconnect - it's shared
  }

  loadTrack(event) {
    const url = event.params.url
    const name = event.params.name
    const containerSelector = this.playerContainerValue

    console.log('Loading track:', { url, name, containerSelector })

    if (!containerSelector) {
      console.error('Player container selector not provided')
      return
    }

    // Get the player container
    const playerContainer = document.querySelector(containerSelector)
    if (!playerContainer) {
      console.error('Player container not found:', containerSelector)
      return
    }

    const trackNameElement = playerContainer.querySelector('span[id^="track_name_"]')
    const audioElement = playerContainer.querySelector('audio')

    // Show the player container
    playerContainer.classList.remove('hidden')

    // Update track name
    if (trackNameElement) {
      trackNameElement.textContent = name
    }

    // Get stem type from name for color
    const stemType = name.toLowerCase()
    const colors = this.constructor.stemColors[stemType] || this.constructor.stemColors.original

    // Stop all other WaveSurfer instances
    this.stopOtherPlayers()

    // Create or get waveform container
    let waveformContainer = playerContainer.querySelector('.waveform-container')
    if (!waveformContainer) {
      waveformContainer = document.createElement('div')
      waveformContainer.className = 'waveform-container mb-3 sm:mb-4'

      // Create waveform wrapper with proper styling
      const waveformWrapper = document.createElement('div')
      waveformWrapper.id = `waveform_${audioElement.id}`
      waveformWrapper.className = 'rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-700/50'
      waveformWrapper.style.height = '60px'
      waveformWrapper.style.minHeight = '60px'
      waveformContainer.appendChild(waveformWrapper)

      // Create time display
      const timeDisplay = document.createElement('div')
      timeDisplay.className = 'flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-2'
      timeDisplay.innerHTML = `
        <span id="current_time_${audioElement.id}">0:00</span>
        <span id="duration_${audioElement.id}">0:00</span>
      `
      waveformContainer.appendChild(timeDisplay)

      // Insert after header area
      const headerArea = playerContainer.querySelector('.flex.items-center.justify-between')
      if (headerArea) {
        headerArea.after(waveformContainer)
      } else {
        playerContainer.appendChild(waveformContainer)
      }
    }

    const waveformId = `waveform_${audioElement.id}`
    const waveformElement = document.getElementById(waveformId)

    // Get or create WaveSurfer instance
    let wavesurfer = this.constructor.wavesurfers.get(audioElement.id)

    if (wavesurfer) {
      // Destroy existing instance to load new track
      wavesurfer.destroy()
    }

    // Create new WaveSurfer instance with stem-specific colors
    wavesurfer = WaveSurfer.create({
      container: waveformElement,
      waveColor: colors.waveColor,
      progressColor: colors.progressColor,
      cursorColor: '#6366f1',
      cursorWidth: 2,
      barWidth: 2,
      barGap: 1,
      barRadius: 2,
      height: 60,
      normalize: true,
      backend: 'WebAudio',
      mediaControls: false,
      responsive: true
    })

    // Store instance
    this.constructor.wavesurfers.set(audioElement.id, wavesurfer)

    // Update time display
    const currentTimeEl = document.getElementById(`current_time_${audioElement.id}`)
    const durationEl = document.getElementById(`duration_${audioElement.id}`)

    // Set up event handlers BEFORE loading audio
    wavesurfer.on('ready', () => {
      console.log('WaveSurfer ready, starting playback')
      if (durationEl) {
        durationEl.textContent = this.formatTime(wavesurfer.getDuration())
      }
      wavesurfer.play()
    })

    wavesurfer.on('audioprocess', () => {
      if (currentTimeEl) {
        currentTimeEl.textContent = this.formatTime(wavesurfer.getCurrentTime())
      }
    })

    wavesurfer.on('seeking', () => {
      if (currentTimeEl) {
        currentTimeEl.textContent = this.formatTime(wavesurfer.getCurrentTime())
      }
    })

    wavesurfer.on('finish', () => {
      console.log('Playback finished')
      this.updatePlayerControls(playerContainer, false)
    })

    wavesurfer.on('play', () => {
      this.updatePlayerControls(playerContainer, true)
    })

    wavesurfer.on('pause', () => {
      this.updatePlayerControls(playerContainer, false)
    })

    wavesurfer.on('error', (error) => {
      console.error('WaveSurfer error:', error)
    })

    // Load the audio AFTER setting up event handlers
    wavesurfer.load(url)

    // Add controls with Plyr as fallback (hidden)
    this.setupPlyrFallback(audioElement, url)
  }

  setupPlyrFallback(audioElement, url) {
    // Update audio element as fallback
    audioElement.src = url
    audioElement.type = url.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav'

    // Hide the raw audio element - WaveSurfer handles playback
    audioElement.style.display = 'none'
  }

  formatTime(seconds) {
    if (isNaN(seconds)) return '0:00'
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  stopOtherPlayers(excludeId = null) {
    // Stop all other WaveSurfer instances except the one with excludeId
    this.constructor.wavesurfers.forEach((ws, id) => {
      if (id !== excludeId && ws.isPlaying()) {
        console.log('Stopping player', id)
        ws.pause()
      }
    })
  }

  updatePlayerControls(playerContainer, isPlaying) {
    // Update play/pause icons in the waveform player controls
    const playIcon = playerContainer.querySelector('[data-waveform-player-target="playIcon"]')
    const pauseIcon = playerContainer.querySelector('[data-waveform-player-target="pauseIcon"]')

    if (playIcon && pauseIcon) {
      playIcon.classList.toggle('hidden', isPlaying)
      pauseIcon.classList.toggle('hidden', !isPlaying)
    }
  }
}
