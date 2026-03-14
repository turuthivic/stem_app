import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Theme controller connected")
    // Load saved theme on connect
    this.loadTheme()
  }

  loadTheme() {
    if (localStorage.getItem('theme') === 'light') {
      document.documentElement.classList.remove('dark')
    } else {
      document.documentElement.classList.add('dark')
    }
  }

  toggle() {
    console.log("Toggle theme called")
    const html = document.documentElement
    if (html.classList.contains('dark')) {
      html.classList.remove('dark')
      localStorage.setItem('theme', 'light')
      console.log("Switched to light mode")
    } else {
      html.classList.add('dark')
      localStorage.setItem('theme', 'dark')
      console.log("Switched to dark mode")
    }
  }
}
