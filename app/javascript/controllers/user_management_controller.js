import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="user-management"
export default class extends Controller {
  static targets = ["addModal", "deleteModal", "deleteMessage", "deleteCheckbox", "deleteButton", "deleteForm"]
  static values = {
    deleteUrl: String,
    deleteEmail: String
  }

  // Add User Modal
  openAddModal() {
    this.addModalTarget.showModal()
  }

  closeAddModal() {
    this.addModalTarget.close()
  }

  // Delete User Modal
  openDeleteModal(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.deleteUrlValue = button.dataset.userManagementDeleteUrl
    this.deleteEmailValue = button.dataset.userManagementDeleteEmail

    // Update message
    this.deleteMessageTarget.textContent = `Are you sure you want to delete user "${this.deleteEmailValue}"? This will permanently delete all their data including flight searches, hotel searches, and real estate follows.`

    // Reset checkbox and button
    this.deleteCheckboxTarget.checked = false
    this.deleteButtonTarget.disabled = true

    // Set form action
    this.deleteFormTarget.action = this.deleteUrlValue

    this.deleteModalTarget.showModal()
  }

  closeDeleteModal() {
    this.deleteModalTarget.close()
  }

  toggleDeleteButton() {
    this.deleteButtonTarget.disabled = !this.deleteCheckboxTarget.checked
  }
}
