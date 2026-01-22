import { Controller } from "@hotwired/stimulus"

// This controller handles the play/pause/stop controls for the waveform player
// It works in conjunction with the audio_player_controller which manages WaveSurfer instances

export default class extends Controller {
  static targets = ["playPauseBtn", "playIcon", "pauseIcon"]

  connect() {
    this.isPlaying = false
    this.audioElement = this.element.querySelector('audio')
  }

  togglePlayPause() {
    // Get the WaveSurfer instance from the audio_player_controller
    const audioPlayerController = this.application.getControllerForElementAndIdentifier(
      document.body,
      'audio-player'
    )

    // Access the static wavesurfers map
    if (window.audioPlayerWavesurfers) {
      const wavesurfer = window.audioPlayerWavesurfers.get(this.audioElement?.id)
      if (wavesurfer) {
        wavesurfer.playPause()
        this.updatePlayPauseUI(wavesurfer.isPlaying())
      }
    }
  }

  stop() {
    if (window.audioPlayerWavesurfers) {
      const wavesurfer = window.audioPlayerWavesurfers.get(this.audioElement?.id)
      if (wavesurfer) {
        wavesurfer.stop()
        this.updatePlayPauseUI(false)
      }
    }
  }

  updatePlayPauseUI(isPlaying) {
    this.isPlaying = isPlaying
    if (this.hasPlayIconTarget && this.hasPauseIconTarget) {
      this.playIconTarget.classList.toggle('hidden', isPlaying)
      this.pauseIconTarget.classList.toggle('hidden', !isPlaying)
    }
  }
}
