import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "fileName", "submitButton", "progress", "progressBar", "progressText", "dropZone"]

  connect() {
    this.updateSubmitButton()
  }

  browse() {
    this.fileInputTarget.click()
  }

  fileSelected() {
    const file = this.fileInputTarget.files[0]
    if (file) {
      if (this.isValidAudioFile(file)) {
        this.showFileName(file.name)
        this.updateSubmitButton()
        this.clearError()
      } else {
        this.showError("Please select a valid audio file (MP3, WAV, FLAC, M4A)")
        this.fileInputTarget.value = ""
        this.updateSubmitButton()
      }
    }
  }

  isValidAudioFile(file) {
    const validExtensions = ['.mp3', '.wav', '.flac', '.m4a', '.mp4']
    const validTypes = ['audio/mpeg', 'audio/wav', 'audio/flac', 'audio/m4a', 'audio/mp4']

    const fileName = file.name.toLowerCase()
    const fileExtension = fileName.substring(fileName.lastIndexOf('.'))

    return validExtensions.includes(fileExtension) || validTypes.includes(file.type)
  }

  showError(message) {
    // Show error message near the file input
    let errorDiv = this.element.querySelector('.file-error')
    if (!errorDiv) {
      errorDiv = document.createElement('div')
      errorDiv.className = 'file-error text-red-600 text-sm mt-2'
      this.fileNameTarget.parentNode.appendChild(errorDiv)
    }
    errorDiv.textContent = message
    errorDiv.classList.remove('hidden')
  }

  clearError() {
    const errorDiv = this.element.querySelector('.file-error')
    if (errorDiv) {
      errorDiv.classList.add('hidden')
    }
  }

  showFileName(name) {
    this.fileNameTarget.textContent = `Selected: ${name}`
    this.fileNameTarget.classList.remove("hidden")
  }

  updateSubmitButton() {
    const hasFile = this.fileInputTarget.files.length > 0
    this.submitButtonTarget.disabled = !hasFile

    // Update tooltip based on state
    if (hasFile) {
      this.submitButtonTarget.title = "Click to upload and process your audio file"
    } else {
      this.submitButtonTarget.title = "Please select a file first"
    }
  }

  // Handle form submission with progress
  submitForm(event) {
    if (this.fileInputTarget.files.length === 0) {
      event.preventDefault()
      return
    }

    this.showProgress()
    this.submitButtonTarget.disabled = true
  }

  showProgress() {
    this.progressTarget.classList.remove("hidden")
    this.progressBarTarget.style.width = "0%"
    this.progressTextTarget.textContent = "Uploading..."

    // Simulate progress (real progress would come from server)
    let progress = 0
    const interval = setInterval(() => {
      progress += Math.random() * 10
      if (progress >= 95) {
        progress = 95
        clearInterval(interval)
        this.progressTextTarget.textContent = "Processing..."
      }
      this.progressBarTarget.style.width = `${progress}%`
    }, 200)
  }

  hideProgress() {
    this.progressTarget.classList.add("hidden")
    this.submitButtonTarget.disabled = false
  }

  reset() {
    this.fileInputTarget.value = ""
    this.fileNameTarget.classList.add("hidden")
    this.updateSubmitButton()
    this.hideProgress()
    this.clearError()
  }
}