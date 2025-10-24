import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { type: String }
  static targets = ["progress", "progressBar", "currentTime", "duration"]

  connect() {
    this.audio = null
    this.isPlaying = false
    this.progressInterval = null
  }

  disconnect() {
    if (this.audio) {
      this.audio.pause()
      this.audio = null
    }
    this.stopProgressTracking()
  }

  play(event) {
    event.preventDefault()

    // Stop any other playing audio
    this.stopOtherPlayers()

    if (!this.audio) {
      this.audio = new Audio(event.currentTarget.href)

      this.audio.addEventListener("ended", () => {
        this.isPlaying = false
        this.stopProgressTracking()
        this.updateButton()
        this.hideProgress()
      })

      this.audio.addEventListener("loadedmetadata", () => {
        this.updateDuration()
      })
    }

    if (this.isPlaying) {
      this.audio.pause()
      this.isPlaying = false
      this.stopProgressTracking()
    } else {
      this.audio.play()
      this.isPlaying = true
      this.startProgressTracking()
    }

    this.updateButton()
  }

  stopOtherPlayers() {
    // Find all other audio player controllers and stop them
    const otherPlayers = document.querySelectorAll('[data-controller~="audio-player"]')
    otherPlayers.forEach(element => {
      if (element !== this.element) {
        const controller = this.application.getControllerForElementAndIdentifier(element, "audio-player")
        if (controller && controller.isPlaying) {
          controller.audio.pause()
          controller.isPlaying = false
          controller.updateButton()
        }
      }
    })
  }

  updateButton() {
    const button = this.element
    const svg = button.querySelector("svg")
    const textSpan = button.querySelector("span")

    if (this.isPlaying) {
      button.classList.add("bg-blue-100", "border-blue-300", "text-blue-700")
      button.classList.remove("text-gray-700")

      // Change to pause icon
      svg.innerHTML = '<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/>'

      // Keep track name visible but add playing indicator
      if (textSpan && !textSpan.hasAttribute('data-original-text')) {
        textSpan.setAttribute('data-original-text', textSpan.textContent)
      }

      this.showProgress()
    } else {
      button.classList.remove("bg-blue-100", "border-blue-300", "text-blue-700")
      button.classList.add("text-gray-700")

      // Change to play icon
      svg.innerHTML = '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/>'

      this.hideProgress()
    }
  }

  startProgressTracking() {
    this.stopProgressTracking()
    this.progressInterval = setInterval(() => {
      this.updateProgress()
    }, 100)
  }

  stopProgressTracking() {
    if (this.progressInterval) {
      clearInterval(this.progressInterval)
      this.progressInterval = null
    }
  }

  updateProgress() {
    if (!this.audio || !this.hasProgressTarget) return

    const currentTime = this.audio.currentTime
    const duration = this.audio.duration

    if (duration > 0) {
      const percentage = (currentTime / duration) * 100
      this.progressBarTarget.style.width = `${percentage}%`

      if (this.hasCurrentTimeTarget) {
        this.currentTimeTarget.textContent = this.formatTime(currentTime)
      }
    }
  }

  updateDuration() {
    if (!this.audio || !this.hasDurationTarget) return

    this.durationTarget.textContent = this.formatTime(this.audio.duration)
  }

  formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  showProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove('hidden')
    }
  }

  hideProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add('hidden')
      if (this.hasProgressBarTarget) {
        this.progressBarTarget.style.width = '0%'
      }
    }
  }
}