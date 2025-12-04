import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="delete-confirm"
export default class extends Controller {
  static targets = ["modal", "message"]
  static values = {
    url: String,
    message: { type: String, default: "Are you sure you want to delete this item?" }
  }

  open(event) {
    event.preventDefault()

    // Get URL and message from the clicked button
    const button = event.currentTarget
    this.urlValue = button.dataset.deleteConfirmUrl
    if (button.dataset.deleteConfirmMessage) {
      this.messageValue = button.dataset.deleteConfirmMessage
    }

    // Update modal message if target exists
    if (this.hasMessageTarget) {
      this.messageTarget.textContent = this.messageValue
    }

    // Open the modal
    this.modalTarget.showModal()
  }

  close() {
    this.modalTarget.close()
  }

  confirm() {
    // Create and submit a form to delete
    const form = document.createElement("form")
    form.method = "POST"
    form.action = this.urlValue
    form.setAttribute("data-turbo", "true")

    // Add CSRF token
    const csrfToken = document.querySelector("meta[name='csrf-token']")?.content
    if (csrfToken) {
      const csrfInput = document.createElement("input")
      csrfInput.type = "hidden"
      csrfInput.name = "authenticity_token"
      csrfInput.value = csrfToken
      form.appendChild(csrfInput)
    }

    // Add method override for DELETE
    const methodInput = document.createElement("input")
    methodInput.type = "hidden"
    methodInput.name = "_method"
    methodInput.value = "delete"
    form.appendChild(methodInput)

    document.body.appendChild(form)
    form.requestSubmit()

    this.close()
  }
}
