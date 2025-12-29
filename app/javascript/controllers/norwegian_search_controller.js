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
    "loadingIndicator",
    "noFlightsMessage"
  ]

  static values = {
    savedSearches: Object,
    selectedDestination: String
  }

  connect() {
    // Store outbound dates data for later use
    this.outboundDatesData = []
    this.inboundDatesData = []

    // If a destination is pre-selected, load its dates
    if (this.selectedDestinationValue) {
      this.loadDatesForDestination(this.selectedDestinationValue)
    } else {
      this.resetForm()
    }
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
    this.hideNoFlightsMessage()
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

  destinationChanged(event) {
    const destinationCode = event.target.value

    if (!destinationCode) {
      this.resetForm()
      return
    }

    this.loadDatesForDestination(destinationCode)
  }

  async loadDatesForDestination(destinationCode) {
    this.showLoading()
    this.hideNoFlightsMessage()

    try {
      const response = await fetch(`/api/norwegian/dates_out?destination_code=${destinationCode}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        this.outboundDatesData = data.dates
        this.populateDateSelect(this.dateOutSelectTarget, data.dates)
        this.dateOutContainerTarget.classList.remove("hidden")
        this.dateInContainerTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
      } else {
        this.dateOutContainerTarget.classList.add("hidden")
        this.dateInContainerTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
        this.showNoFlightsMessage("No flights available for this destination")
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
    const destinationCode = this.destinationSelectTarget.value

    if (!dateOut || !destinationCode) {
      this.dateInContainerTarget.classList.add("hidden")
      this.submitButtonTarget.disabled = true
      return
    }

    this.showLoading()
    this.hideNoFlightsMessage()

    try {
      const response = await fetch(`/api/norwegian/dates_in?destination_code=${destinationCode}&date_out=${dateOut}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        // Filter dates to only show those after date_out
        let filteredDates = data.dates.filter(d => d.date > dateOut)

        // Filter out already saved date_in values for this destination + date_out
        const savedForDestination = this.savedSearchesValue[destinationCode] || {}
        const savedDatesIn = savedForDestination[dateOut] || []
        filteredDates = filteredDates.filter(d => !savedDatesIn.includes(d.date))

        if (filteredDates.length > 0) {
          this.inboundDatesData = filteredDates
          this.populateDateSelect(this.dateInSelectTarget, filteredDates)
          this.dateInContainerTarget.classList.remove("hidden")
          this.submitButtonTarget.disabled = true
        } else {
          this.dateInContainerTarget.classList.add("hidden")
          this.submitButtonTarget.disabled = true
          this.showNoFlightsMessage("All available return dates for this outbound flight are already saved")
        }
      } else {
        this.dateInContainerTarget.classList.add("hidden")
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
