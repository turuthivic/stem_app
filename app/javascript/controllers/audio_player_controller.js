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
    const icon = button.querySelector("svg")

    if (this.isPlaying) {
      button.classList.add("bg-blue-100", "text-blue-700")
      // Change icon to pause (if you want to implement this)
    } else {
      button.classList.remove("bg-blue-100", "text-blue-700")
      // Change icon to play (if you want to implement this)
    }
  }
}