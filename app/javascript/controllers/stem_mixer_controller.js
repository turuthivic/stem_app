import { Controller } from "@hotwired/stimulus"
import WaveSurfer from "wavesurfer.js"

export default class extends Controller {
  static targets = ["checkbox", "slider", "volumeLabel", "mixControls"]
  static values = {
    audioFileId: Number,
    mixUrl: String,
    playerContainer: String
  }

  connect() {
    this.wavesurfer = null
    this.volumes = new Map()

    // Initialize default volumes
    this.checkboxTargets.forEach(cb => {
      this.volumes.set(cb.value, 1.0)
    })

    this.updateMixControls()
  }

  disconnect() {
    if (this.wavesurfer) {
      this.wavesurfer.stop()
      this.wavesurfer.destroy()
      this.wavesurfer = null
    }
  }

  toggleStem(event) {
    this.updateMixControls()
  }

  updateVolume(event) {
    const slider = event.target
    const stemType = slider.dataset.stemType
    const volume = parseFloat(slider.value)

    // Store volume
    this.volumes.set(stemType, volume)

    // Update label
    const label = this.volumeLabelTargets.find(l => l.dataset.stemType === stemType)
    if (label) {
      label.textContent = `${Math.round(volume * 100)}%`
    }
  }

  getSelectedStems() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }

  getSelectedStemsWithVolumes() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => ({
        stem: cb.value,
        volume: this.volumes.get(cb.value) || 1.0
      }))
  }

  updateMixControls() {
    const selectedStems = this.getSelectedStems()
    const showControls = selectedStems.length >= 2

    if (this.hasMixControlsTarget) {
      this.mixControlsTarget.classList.toggle('hidden', !showControls)
    }
  }

  async playMix() {
    const selectedStems = this.getSelectedStems()
    if (selectedStems.length < 2) return

    // Stop any other players first
    this.stopOtherPlayers()

    // Build the mix URL with stems and volumes
    const stemsWithVolumes = this.getSelectedStemsWithVolumes()
    const volumeParams = stemsWithVolumes.map(s => `${s.stem}:${s.volume}`).join(',')
    const mixAudioUrl = `${this.mixUrlValue}?stems=${selectedStems.join(',')}&volumes=${volumeParams}&format=stream`

    // Get the player container
    const playerContainer = document.querySelector(`#player_container_${this.audioFileIdValue}`)
    if (!playerContainer) {
      console.error('Player container not found')
      return
    }

    const audioElement = playerContainer.querySelector('audio')
    const trackNameElement = playerContainer.querySelector('span[id^="track_name_"]')

    // Show the player container
    playerContainer.classList.remove('hidden')

    // Update track name to show it's a mix
    if (trackNameElement) {
      const stemNames = selectedStems.map(s => s.charAt(0).toUpperCase() + s.slice(1)).join(' + ')
      trackNameElement.textContent = `Mix: ${stemNames}`
    }

    // Create or get waveform container
    let waveformContainer = playerContainer.querySelector('.waveform-container')
    if (!waveformContainer) {
      waveformContainer = document.createElement('div')
      waveformContainer.className = 'waveform-container mb-4'

      const waveformWrapper = document.createElement('div')
      waveformWrapper.id = `waveform_${audioElement.id}`
      waveformWrapper.className = 'rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-700/50'
      waveformWrapper.style.height = '80px'
      waveformContainer.appendChild(waveformWrapper)

      const timeDisplay = document.createElement('div')
      timeDisplay.className = 'flex justify-between text-xs text-gray-500 dark:text-gray-400 mt-2'
      timeDisplay.innerHTML = `
        <span id="current_time_${audioElement.id}">0:00</span>
        <span id="duration_${audioElement.id}">0:00</span>
      `
      waveformContainer.appendChild(timeDisplay)

      const trackNameArea = playerContainer.querySelector('.flex.items-center.justify-between')
      if (trackNameArea) {
        trackNameArea.after(waveformContainer)
      } else {
        playerContainer.appendChild(waveformContainer)
      }
    }

    const waveformId = `waveform_${audioElement.id}`
    const waveformElement = document.getElementById(waveformId)

    // Destroy existing WaveSurfer if any
    if (this.wavesurfer) {
      this.wavesurfer.destroy()
    }

    // Also destroy any WaveSurfer from audio_player_controller
    if (window.audioPlayerWavesurfers && window.audioPlayerWavesurfers.has(audioElement.id)) {
      window.audioPlayerWavesurfers.get(audioElement.id).destroy()
      window.audioPlayerWavesurfers.delete(audioElement.id)
    }

    // Create WaveSurfer with gradient colors for mix
    this.wavesurfer = WaveSurfer.create({
      container: waveformElement,
      waveColor: '#a78bfa', // Purple-400 for mix
      progressColor: '#7c3aed', // Purple-600
      cursorColor: '#6366f1',
      cursorWidth: 2,
      barWidth: 2,
      barGap: 1,
      barRadius: 2,
      height: 80,
      normalize: true,
      backend: 'WebAudio'
    })

    // Load the mixed audio from server
    this.wavesurfer.load(mixAudioUrl)

    const currentTimeEl = document.getElementById(`current_time_${audioElement.id}`)
    const durationEl = document.getElementById(`duration_${audioElement.id}`)

    this.wavesurfer.on('ready', () => {
      console.log('Mix WaveSurfer ready, starting playback')
      if (durationEl) {
        durationEl.textContent = this.formatTime(this.wavesurfer.getDuration())
      }
      this.wavesurfer.play()
    })

    this.wavesurfer.on('audioprocess', () => {
      if (currentTimeEl) {
        currentTimeEl.textContent = this.formatTime(this.wavesurfer.getCurrentTime())
      }
    })

    this.wavesurfer.on('seeking', () => {
      if (currentTimeEl) {
        currentTimeEl.textContent = this.formatTime(this.wavesurfer.getCurrentTime())
      }
    })

    this.wavesurfer.on('finish', () => {
      console.log('Mix playback finished')
      this.updatePlayerControls(playerContainer, false)
    })

    this.wavesurfer.on('play', () => {
      this.updatePlayerControls(playerContainer, true)
    })

    this.wavesurfer.on('pause', () => {
      this.updatePlayerControls(playerContainer, false)
    })

    this.wavesurfer.on('error', (error) => {
      console.error('Mix WaveSurfer error:', error)
    })

    // Store reference globally so waveform_player_controller can access it
    window.audioPlayerWavesurfers = window.audioPlayerWavesurfers || new Map()
    window.audioPlayerWavesurfers.set(audioElement.id, this.wavesurfer)
  }

  stopOtherPlayers() {
    // Stop all WaveSurfer instances
    if (window.audioPlayerWavesurfers) {
      window.audioPlayerWavesurfers.forEach((ws, id) => {
        if (ws.isPlaying()) {
          ws.pause()
        }
      })
    }
  }

  updatePlayerControls(playerContainer, isPlaying) {
    const playIcon = playerContainer.querySelector('[data-waveform-player-target="playIcon"]')
    const pauseIcon = playerContainer.querySelector('[data-waveform-player-target="pauseIcon"]')

    if (playIcon && pauseIcon) {
      playIcon.classList.toggle('hidden', isPlaying)
      pauseIcon.classList.toggle('hidden', !isPlaying)
    }
  }

  formatTime(seconds) {
    if (isNaN(seconds)) return '0:00'
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  downloadMix() {
    const selectedStems = this.getSelectedStems()
    if (selectedStems.length < 2) return

    const volumeParams = selectedStems.map(stem => {
      const volume = this.volumes.get(stem) || 1.0
      return `${stem}:${volume}`
    }).join(',')

    const url = `${this.mixUrlValue}?stems=${selectedStems.join(',')}&volumes=${volumeParams}`

    window.location.href = url
  }
}
