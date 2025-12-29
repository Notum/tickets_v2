import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dateOutSelect",
    "dateInSelect",
    "dateInContainer",
    "tripDuration",
    "submitButton",
    "loadingIndicator",
    "noFlightsMessage"
  ]

  static values = {
    savedSearches: Object
  }

  connect() {
    // Store dates data for later use
    this.outboundDatesData = []
    this.inboundDatesData = []

    // Load outbound dates immediately (hardcoded RIX-DXB route)
    this.loadOutboundDates()
  }

  showNoFlightsMessage(message) {
    if (this.hasNoFlightsMessageTarget) {
      this.noFlightsMessageTarget.textContent = message
      this.noFlightsMessageTarget.classList.remove("hidden")
    }
  }

  hideNoFlightsMessage() {
    if (this.hasNoFlightsMessageTarget) {
      this.noFlightsMessageTarget.classList.add("hidden")
    }
  }

  async loadOutboundDates() {
    this.showLoading()
    this.hideNoFlightsMessage()

    try {
      const response = await fetch("/api/flydubai/dates_out")
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        this.outboundDatesData = data.dates
        this.populateDateSelect(this.dateOutSelectTarget, data.dates)
        this.dateInSelectTarget.disabled = true
        this.submitButtonTarget.disabled = true
      } else {
        this.submitButtonTarget.disabled = true
        this.showNoFlightsMessage("No flights available. Please try again later.")
      }
    } catch (error) {
      console.error("Error fetching outbound dates:", error)
      this.showNoFlightsMessage("Failed to fetch available dates. Please try again.")
    } finally {
      this.hideLoading()
    }
  }

  async dateOutChanged(event) {
    const dateOut = event.target.value

    if (!dateOut) {
      this.dateInSelectTarget.disabled = true
      this.dateInSelectTarget.innerHTML = '<option value="">Select outbound date first</option>'
      this.submitButtonTarget.disabled = true
      return
    }

    this.showLoading()
    this.hideNoFlightsMessage()

    try {
      const response = await fetch(`/api/flydubai/dates_in?date_out=${dateOut}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        // Filter dates to only show those after date_out
        let filteredDates = data.dates.filter(d => d.date > dateOut)

        // Filter out already saved date_in values for this date_out
        const savedDatesIn = this.savedSearchesValue[dateOut] || []
        filteredDates = filteredDates.filter(d => !savedDatesIn.includes(d.date))

        if (filteredDates.length > 0) {
          this.inboundDatesData = filteredDates
          this.populateDateSelect(this.dateInSelectTarget, filteredDates)
          this.dateInSelectTarget.disabled = false
          this.submitButtonTarget.disabled = true
        } else {
          this.dateInSelectTarget.disabled = true
          this.dateInSelectTarget.innerHTML = '<option value="">No dates available</option>'
          this.submitButtonTarget.disabled = true
          this.showNoFlightsMessage("All available return dates for this outbound flight are already saved")
        }
      } else {
        this.dateInSelectTarget.disabled = true
        this.dateInSelectTarget.innerHTML = '<option value="">No dates available</option>'
        this.submitButtonTarget.disabled = true
        this.showNoFlightsMessage("No return flights available for this date")
      }
    } catch (error) {
      console.error("Error fetching return dates:", error)
      this.showNoFlightsMessage("Failed to fetch return dates. Please try again.")
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

    dates.forEach(item => {
      const date = new Date(item.date)
      const option = document.createElement("option")
      option.value = item.date

      // Format: "Mon, Dec 25, 2025 (Direct)"
      let label = this.formatDate(date)
      if (item.is_direct) {
        label += " (Direct)"
      }

      option.textContent = label
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
