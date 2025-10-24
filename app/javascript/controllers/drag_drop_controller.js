import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [""]

  connect() {
    this.element.addEventListener("click", this.handleClick.bind(this))
  }

  handleClick(event) {
    // Find the file input in the upload controller
    const uploadController = this.application.getControllerForElementAndIdentifier(
      this.element.closest('[data-controller~="upload"]'),
      "upload"
    )
    if (uploadController) {
      uploadController.browse()
    }
  }

  dragover(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.add("border-blue-400", "bg-blue-50")
  }

  dragleave(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.remove("border-blue-400", "bg-blue-50")
  }

  drop(event) {
    event.preventDefault()
    event.stopPropagation()
    this.element.classList.remove("border-blue-400", "bg-blue-50")

    const files = event.dataTransfer.files
    if (files.length > 0) {
      const file = files[0]

      // Check if it's an audio file
      if (file.type.startsWith("audio/")) {
        // Find the upload controller and set the file
        const uploadController = this.application.getControllerForElementAndIdentifier(
          this.element.closest('[data-controller~="upload"]'),
          "upload"
        )

        if (uploadController) {
          // Create a new FileList with the dropped file
          const dt = new DataTransfer()
          dt.items.add(file)
          uploadController.fileInputTarget.files = dt.files

          // Trigger the file selected handler
          uploadController.fileSelected()
        }
      } else {
        // Show error for non-audio files
        this.showError("Please drop an audio file (MP3, WAV, FLAC, etc.)")
      }
    }
  }

  showError(message) {
    // Create a temporary error message
    const errorDiv = document.createElement("div")
    errorDiv.className = "bg-red-50 border border-red-200 text-red-800 px-4 py-3 rounded-lg mt-4"
    errorDiv.textContent = message

    this.element.appendChild(errorDiv)

    // Remove after 3 seconds
    setTimeout(() => {
      errorDiv.remove()
    }, 3000)
  }
}