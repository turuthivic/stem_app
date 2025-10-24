import { Controller } from "@hotwired/stimulus"
import Plyr from "plyr"

export default class extends Controller {
  static values = { url: String, type: String }
  static targets = ["player"]

  connect() {
    this.initializePlayer()
  }

  disconnect() {
    if (this.player) {
      this.player.destroy()
      this.player = null
    }
  }

  initializePlayer() {
    if (!this.hasPlayerTarget) return

    this.player = new Plyr(this.playerTarget, {
      controls: [
        'play',
        'progress',
        'current-time',
        'duration',
        'mute',
        'volume',
        'settings',
        'download'
      ],
      settings: ['speed'],
      speed: { selected: 1, options: [0.5, 0.75, 1, 1.25, 1.5, 2] },
      hideControls: false,
      resetOnEnd: true
    })

    // Stop other players when this one starts
    this.player.on('play', () => {
      this.stopOtherPlayers()
    })
  }

  stopOtherPlayers() {
    // Find all other audio player controllers and stop them
    const otherPlayers = document.querySelectorAll('[data-controller~="audio-player"]')
    otherPlayers.forEach(element => {
      if (element !== this.element) {
        const controller = this.application.getControllerForElementAndIdentifier(element, "audio-player")
        if (controller && controller.player && !controller.player.paused) {
          controller.player.pause()
        }
      }
    })
  }
}