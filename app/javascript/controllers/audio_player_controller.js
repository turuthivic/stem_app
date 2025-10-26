import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    playerContainer: String
  }

  // Store Plyr instances globally to share across button instances
  static players = new Map()

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

    // Get the player container and related elements
    const playerContainer = document.querySelector(containerSelector)
    if (!playerContainer) {
      console.error('Player container not found:', containerSelector)
      return
    }

    const audioElement = playerContainer.querySelector('audio')
    const trackNameElement = playerContainer.querySelector('span[id^="track_name_"]')

    if (!audioElement) {
      console.error('Audio element not found in container')
      return
    }

    // Stop other players
    this.stopOtherPlayers()

    // Show the player container
    playerContainer.classList.remove('hidden')

    // Update track name
    if (trackNameElement) {
      trackNameElement.textContent = name
    }

    // Check if Plyr instance exists
    let player = this.constructor.players.get(audioElement.id)

    if (player) {
      // Player exists - update the underlying audio element directly
      console.log('Reusing existing Plyr instance, changing source to:', url)

      // Pause current playback
      player.pause()

      // Update the underlying audio element's src directly (bypasses Plyr's source API)
      audioElement.src = url
      audioElement.type = url.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav'

      // Load the new source
      audioElement.load()

      // Play when ready
      const playWhenReady = () => {
        console.log('New track loaded, starting playback')
        player.play().catch(error => {
          console.error('Error playing new track:', error)
        })
        audioElement.removeEventListener('canplay', playWhenReady)
      }

      audioElement.addEventListener('canplay', playWhenReady, { once: true })

    } else {
      // No player exists - create a new one
      console.log('Creating new Plyr instance for', audioElement.id)

      // Set the source on the raw audio element BEFORE initializing Plyr
      audioElement.src = url
      audioElement.type = url.endsWith('.mp3') ? 'audio/mpeg' : 'audio/wav'

      player = new Plyr(audioElement, {
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

      // Store the player instance
      this.constructor.players.set(audioElement.id, player)

      // Stop other players when this one starts
      player.on('play', () => {
        console.log('Play event triggered for', audioElement.id)
        this.stopOtherPlayers(audioElement.id)
      })

      player.on('error', (event) => {
        console.error('Plyr error event:', event)
      })

      // Add ready handler to auto-play once loaded
      player.on('canplay', () => {
        console.log('Audio can play, starting playback')
        player.play().catch(error => {
          console.error('Error auto-playing audio:', error)
        })
      })
    }
  }

  stopOtherPlayers(excludeId = null) {
    // Stop all other Plyr instances except the one with excludeId
    this.constructor.players.forEach((player, id) => {
      if (id !== excludeId && !player.paused) {
        console.log('Stopping player', id)
        player.pause()
      }
    })
  }
}
