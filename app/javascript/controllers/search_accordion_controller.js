import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="search-accordion"
export default class extends Controller {
  static targets = ["content", "icon"]
  static values = {
    section: String,
    expanded: { type: Boolean, default: true }
  }

  connect() {
    // Set initial state based on expanded value
    this.updateUI()
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    this.updateUI()
    this.persistState()
  }

  updateUI() {
    if (this.expandedValue) {
      this.contentTarget.classList.remove("hidden")
      this.iconTarget.classList.remove("rotate-180")
    } else {
      this.contentTarget.classList.add("hidden")
      this.iconTarget.classList.add("rotate-180")
    }
  }

  async persistState() {
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content

    try {
      await fetch("/api/user_preferences/accordion_state", {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": csrfToken
        },
        body: JSON.stringify({
          section: this.sectionValue,
          expanded: this.expandedValue
        })
      })
    } catch (error) {
      console.error("Failed to save accordion state:", error)
    }
  }
}
