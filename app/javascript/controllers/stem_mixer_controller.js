import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "mixControls", "playButton", "stopButton", "downloadButton"]
  static values = {
    audioFileId: Number,
    mixUrl: String
  }

  connect() {
    this.audioContext = null
    this.audioBuffers = new Map()
    this.sourceNodes = []
    this.isPlaying = false
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

    // Stop any current playback
    this.stopMix()

    // Initialize audio context if needed
    if (!this.audioContext) {
      this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
    }

    // Resume context if suspended (browser autoplay policy)
    if (this.audioContext.state === 'suspended') {
      await this.audioContext.resume()
    }

    // Update UI
    this.setPlayingState(true)

    try {
      // Load all selected stems
      const loadPromises = selectedStems.map(stem => this.loadStem(stem))
      const buffers = await Promise.all(loadPromises)

      // Start all sources at the same time
      const startTime = this.audioContext.currentTime + 0.1
      buffers.forEach(buffer => {
        if (buffer) {
          const source = this.audioContext.createBufferSource()
          source.buffer = buffer
          source.connect(this.audioContext.destination)
          source.start(startTime)
          source.onended = () => this.onSourceEnded()
          this.sourceNodes.push(source)
        }
      })
    } catch (error) {
      console.error('Error playing mix:', error)
      this.setPlayingState(false)
    }
  }

  async loadStem(stemType) {
    // Check cache
    const cacheKey = `${this.audioFileIdValue}_${stemType}`
    if (this.audioBuffers.has(cacheKey)) {
      return this.audioBuffers.get(cacheKey)
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
      return audioBuffer
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
      this.setPlayingState(false)
      this.sourceNodes = []
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
    this.setPlayingState(false)
  }

  setPlayingState(isPlaying) {
    this.isPlaying = isPlaying

    if (this.hasPlayButtonTarget && this.hasStopButtonTarget) {
      this.playButtonTarget.classList.toggle('hidden', isPlaying)
      this.stopButtonTarget.classList.toggle('hidden', !isPlaying)
    }
  }

  downloadMix() {
    const selectedStems = this.getSelectedStems()
    if (selectedStems.length < 2) return

    // Build the download URL with stem parameters
    const url = `${this.mixUrlValue}?stems=${selectedStems.join(',')}`

    // Trigger download
    window.location.href = url
  }
}
