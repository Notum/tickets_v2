import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "destinationSelect",
    "dateOutSelect",
    "dateInSelect",
    "dateOutContainer",
    "dateInContainer",
    "tripDuration",
    "submitButton",
    "loadingIndicator"
  ]

  connect() {
    this.resetForm()
  }

  resetForm() {
    if (this.hasDateOutContainerTarget) {
      this.dateOutContainerTarget.classList.add("hidden")
    }
    if (this.hasDateInContainerTarget) {
      this.dateInContainerTarget.classList.add("hidden")
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
    }
  }

  async destinationChanged(event) {
    const destinationCode = event.target.value

    if (!destinationCode) {
      this.resetForm()
      return
    }

    this.showLoading()

    try {
      const response = await fetch(`/api/ryanair/dates_out?destination_code=${destinationCode}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        this.populateDateSelect(this.dateOutSelectTarget, data.dates)
        this.dateOutContainerTarget.classList.remove("hidden")
        this.dateInContainerTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
      } else {
        alert("No available outbound dates for this destination")
        this.resetForm()
      }
    } catch (error) {
      console.error("Error fetching outbound dates:", error)
      alert("Failed to fetch available dates. Please try again.")
    } finally {
      this.hideLoading()
    }
  }

  async dateOutChanged(event) {
    const dateOut = event.target.value
    const destinationCode = this.destinationSelectTarget.value

    if (!dateOut || !destinationCode) {
      this.dateInContainerTarget.classList.add("hidden")
      this.submitButtonTarget.disabled = true
      return
    }

    this.showLoading()

    try {
      const response = await fetch(`/api/ryanair/dates_in?destination_code=${destinationCode}&date_out=${dateOut}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        // Filter dates to only show those after date_out
        const filteredDates = data.dates.filter(d => d > dateOut)
        this.populateDateSelect(this.dateInSelectTarget, filteredDates)
        this.dateInContainerTarget.classList.remove("hidden")
        this.submitButtonTarget.disabled = true
      } else {
        alert("No available return dates for this flight")
        this.dateInContainerTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
      }
    } catch (error) {
      console.error("Error fetching return dates:", error)
      alert("Failed to fetch return dates. Please try again.")
    } finally {
      this.hideLoading()
    }
  }

  dateInChanged(event) {
    const dateIn = event.target.value
    const dateOut = this.dateOutSelectTarget.value

    if (dateIn && dateOut) {
      this.submitButtonTarget.disabled = false
      this.updateTripDuration(dateOut, dateIn)
    } else {
      this.submitButtonTarget.disabled = true
      if (this.hasTripDurationTarget) {
        this.tripDurationTarget.textContent = ""
      }
    }
  }

  populateDateSelect(selectElement, dates) {
    selectElement.innerHTML = '<option value="">Select a date</option>'

    dates.forEach(dateStr => {
      const date = new Date(dateStr)
      const option = document.createElement("option")
      option.value = dateStr
      option.textContent = this.formatDate(date)
      selectElement.appendChild(option)
    })
  }

  formatDate(date) {
    const options = { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' }
    return date.toLocaleDateString('en-US', options)
  }

  updateTripDuration(dateOut, dateIn) {
    if (!this.hasTripDurationTarget) return

    const start = new Date(dateOut)
    const end = new Date(dateIn)
    const diffTime = Math.abs(end - start)
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

    this.tripDurationTarget.textContent = `Trip duration: ${diffDays} day${diffDays !== 1 ? 's' : ''}`
  }

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove("hidden")
    }
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add("hidden")
    }
  }
}
