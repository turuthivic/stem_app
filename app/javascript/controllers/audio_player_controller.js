import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { type: String }

  connect() {
    this.audio = null
    this.isPlaying = false
  }

  disconnect() {
    if (this.audio) {
      this.audio.pause()
      this.audio = null
    }
  }

  play(event) {
    event.preventDefault()

    // Stop any other playing audio
    this.stopOtherPlayers()

    if (!this.audio) {
      this.audio = new Audio(event.currentTarget.href)
      this.audio.addEventListener("ended", () => {
        this.isPlaying = false
        this.updateButton()
      })
    }

    if (this.isPlaying) {
      this.audio.pause()
      this.isPlaying = false
    } else {
      this.audio.play()
      this.isPlaying = true
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

      // Update text to show "Playing..."
      if (textSpan) {
        textSpan.setAttribute('data-original-text', textSpan.textContent)
        textSpan.textContent = 'Playing...'
      }
    } else {
      button.classList.remove("bg-blue-100", "border-blue-300", "text-blue-700")
      button.classList.add("text-gray-700")

      // Change to play icon
      svg.innerHTML = '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM9.555 7.168A1 1 0 008 8v4a1 1 0 001.555.832l3-2a1 1 0 000-1.664l-3-2z" clip-rule="evenodd"/>'

      // Restore original text
      if (textSpan && textSpan.hasAttribute('data-original-text')) {
        textSpan.textContent = textSpan.getAttribute('data-original-text')
      }
    }
  }
}