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
    "priceOutInput",
    "priceInInput",
    "isDirectOutInput",
    "isDirectInInput",
    "priceSummary",
    "totalPrice",
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
    if (this.hasPriceSummaryTarget) {
      this.priceSummaryTarget.classList.add("hidden")
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
      const response = await fetch(`/api/airbaltic/dates_out?destination_code=${destinationCode}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        this.outboundDatesData = data.dates
        this.populateDateSelectWithPrices(this.dateOutSelectTarget, data.dates)
        this.dateOutContainerTarget.classList.remove("hidden")
        this.dateInContainerTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
        this.priceSummaryTarget.classList.add("hidden")
      } else {
        this.dateOutContainerTarget.classList.add("hidden")
        this.dateInContainerTarget.classList.add("hidden")
        this.priceSummaryTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
        this.showNoFlightsMessage("No direct flights available for this destination")
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
      this.priceSummaryTarget.classList.add("hidden")
      return
    }

    // Store selected outbound data
    this.selectedOutbound = this.outboundDatesData.find(d => d.date === dateOut)

    this.showLoading()
    this.hideNoFlightsMessage()

    try {
      const response = await fetch(`/api/airbaltic/dates_in?destination_code=${destinationCode}&date_out=${dateOut}`)
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
          this.populateDateSelectWithPrices(this.dateInSelectTarget, filteredDates)
          this.dateInContainerTarget.classList.remove("hidden")
          this.submitButtonTarget.disabled = true
          this.priceSummaryTarget.classList.add("hidden")
        } else {
          this.dateInContainerTarget.classList.add("hidden")
          this.submitButtonTarget.disabled = true
          this.priceSummaryTarget.classList.add("hidden")
          this.showNoFlightsMessage("All available return dates for this outbound flight are already saved")
        }
      } else {
        this.dateInContainerTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
        this.priceSummaryTarget.classList.add("hidden")
        this.showNoFlightsMessage("No direct return flights available for this date")
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

      // Store selected inbound data and update prices
      this.selectedInbound = this.inboundDatesData.find(d => d.date === dateIn)
      this.updatePriceSummary()
    } else {
      this.submitButtonTarget.disabled = true
      if (this.hasTripDurationTarget) {
        this.tripDurationTarget.textContent = ""
      }
      this.priceSummaryTarget.classList.add("hidden")
    }
  }

  populateDateSelectWithPrices(selectElement, dates) {
    selectElement.innerHTML = '<option value="">Select a date</option>'

    dates.forEach(item => {
      const date = new Date(item.date)
      const option = document.createElement("option")
      option.value = item.date

      // Format: "Mon, Dec 25, 2025 - €179.99 (Direct)" or "Mon, Dec 25, 2025 - Price N/A"
      let label = this.formatDate(date)
      if (item.price !== null && item.price !== undefined && item.price > 0) {
        label += ` - €${item.price.toFixed(2)}`
      } else {
        label += " - Price N/A"
      }
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

  updatePriceSummary() {
    if (!this.selectedOutbound || !this.selectedInbound) return

    const priceOut = this.selectedOutbound.price
    const priceIn = this.selectedInbound.price

    // Update hidden inputs
    this.priceOutInputTarget.value = priceOut || ""
    this.priceInInputTarget.value = priceIn || ""
    this.isDirectOutInputTarget.value = this.selectedOutbound.is_direct
    this.isDirectInInputTarget.value = this.selectedInbound.is_direct

    // Update display - handle null prices
    if (priceOut && priceIn && priceOut > 0 && priceIn > 0) {
      const totalPrice = priceOut + priceIn
      this.totalPriceTarget.textContent = `€${totalPrice.toFixed(2)}`
    } else {
      this.totalPriceTarget.textContent = "Price unavailable"
    }
    this.priceSummaryTarget.classList.remove("hidden")
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
