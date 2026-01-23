import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "slider", "volumeLabel", "mixControls"]
  static values = {
    audioFileId: Number,
    mixUrl: String
  }

  connect() {
    this.audioContext = null
    this.audioBuffers = new Map()
    this.gainNodes = new Map()
    this.sourceNodes = []
    this.isPlaying = false
    this.volumes = new Map()

    // Initialize default volumes
    this.checkboxTargets.forEach(cb => {
      this.volumes.set(cb.value, 1.0)
    })

    this.updateMixControls()
  }

  disconnect() {
    this.stopMix()
    if (this.audioContext) {
      this.audioContext.close()
    }
  }

  toggleStem(event) {
    this.updateMixControls()

    // If currently playing, restart mix with new selection
    if (this.isPlaying) {
      this.playMix()
    }
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

    // Update gain node in real-time if playing
    if (this.gainNodes.has(stemType)) {
      const gainNode = this.gainNodes.get(stemType)
      gainNode.gain.setValueAtTime(volume, this.audioContext.currentTime)
    }
  }

  getSelectedStems() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
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

    // Stop any current playback and other players
    this.stopMix()
    this.stopOtherPlayers()

    // Initialize audio context if needed
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
    }

    // Resume context if suspended (browser autoplay policy)
    if (this.audioContext.state === 'suspended') {
      await this.audioContext.resume()
    }

    // Update UI
    this.isPlaying = true

    // Show player container with mix info
    const playerContainer = document.querySelector(`#player_container_${this.audioFileIdValue}`)
    if (playerContainer) {
      playerContainer.classList.remove('hidden')
      const trackNameElement = playerContainer.querySelector('span[id^="track_name_"]')
      if (trackNameElement) {
        const stemNames = selectedStems.map(s => s.charAt(0).toUpperCase() + s.slice(1)).join(' + ')
        trackNameElement.textContent = `Mix: ${stemNames}`
      }
    }

    try {
      // Load all selected stems
      const loadPromises = selectedStems.map(stem => this.loadStem(stem))
      const bufferResults = await Promise.all(loadPromises)

      // Clear old gain nodes
      this.gainNodes.clear()

      // Start all sources at the same time with individual gain nodes
      const startTime = this.audioContext.currentTime + 0.1
      bufferResults.forEach((result, index) => {
        if (result && result.buffer) {
          const stemType = selectedStems[index]

          // Create source
          const source = this.audioContext.createBufferSource()
          source.buffer = result.buffer

          // Create gain node for volume control
          const gainNode = this.audioContext.createGain()
          const volume = this.volumes.get(stemType) || 1.0
          gainNode.gain.setValueAtTime(volume, this.audioContext.currentTime)

          // Connect: source -> gain -> destination
          source.connect(gainNode)
          gainNode.connect(this.audioContext.destination)

          // Store gain node for real-time updates
          this.gainNodes.set(stemType, gainNode)

          source.start(startTime)
          source.onended = () => this.onSourceEnded()
          this.sourceNodes.push(source)
        }
      })
    } catch (error) {
      console.error('Error playing mix:', error)
      this.isPlaying = false
    }
  }

  async loadStem(stemType) {
    // Check cache
    const cacheKey = `${this.audioFileIdValue}_${stemType}`
    if (this.audioBuffers.has(cacheKey)) {
      return { buffer: this.audioBuffers.get(cacheKey), stemType }
    }

    // Find the URL from the checkbox data attribute
    const checkbox = this.checkboxTargets.find(cb => cb.value === stemType)
    if (!checkbox) return null

    const url = checkbox.dataset.stemUrl
    if (!url) return null

    try {
      const response = await fetch(url)
      const arrayBuffer = await response.arrayBuffer()
      const audioBuffer = await this.audioContext.decodeAudioData(arrayBuffer)
      this.audioBuffers.set(cacheKey, audioBuffer)
      return { buffer: audioBuffer, stemType }
    } catch (error) {
      console.error(`Error loading stem ${stemType}:`, error)
      return null
    }
  }

  onSourceEnded() {
    // Check if all sources have ended
    const allEnded = this.sourceNodes.every(source => {
      try {
        return source.context.currentTime >= source.buffer.duration
      } catch {
        return true
      }
    })

    if (allEnded) {
      this.isPlaying = false
      this.sourceNodes = []
      this.gainNodes.clear()
    }
  }

  stopMix() {
    this.sourceNodes.forEach(source => {
      try {
        source.stop()
      } catch (e) {
        // Source may have already stopped
      }
    })
    this.sourceNodes = []
    this.gainNodes.clear()
    this.isPlaying = false
  }

  stopOtherPlayers() {
    // Stop all WaveSurfer instances from individual stem playback
    if (window.audioPlayerWavesurfers) {
      window.audioPlayerWavesurfers.forEach((ws) => {
        if (ws.isPlaying()) {
          ws.pause()
        }
      })
    }
  }

  downloadMix() {
    const selectedStems = this.getSelectedStems()
    if (selectedStems.length < 2) return

    // Build the download URL with stem parameters and volumes
    const volumeParams = selectedStems.map(stem => {
      const volume = this.volumes.get(stem) || 1.0
      return `${stem}:${volume}`
    }).join(',')

    const url = `${this.mixUrlValue}?stems=${selectedStems.join(',')}&volumes=${volumeParams}`

    // Trigger download
    window.location.href = url
  }
}
