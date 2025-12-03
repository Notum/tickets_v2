import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeOnClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.element.removeAttribute("open")
    }
  }
}
