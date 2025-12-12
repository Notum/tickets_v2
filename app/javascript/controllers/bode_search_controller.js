import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "destinationSelect",
    "flightContainer",
    "flightSelect",
    "dateOut",
    "dateIn",
    "tripInfo",
    "submitButton",
    "loadingIndicator"
  ]

  static values = {
    savedSearches: Object,
    selectedDestination: String
  }

  connect() {
    this.flights = []

    // If a destination is pre-selected, load its flights
    if (this.selectedDestinationValue) {
      this.destinationChanged()
    }
  }

  async destinationChanged() {
    const destinationId = this.destinationSelectTarget.value

    // Reset flight selection
    this.flightSelectTarget.innerHTML = '<option value="">Select a flight</option>'
    this.dateOutTarget.value = ""
    this.dateInTarget.value = ""
    this.tripInfoTarget.textContent = "\u00A0"
    this.submitButtonTarget.disabled = true
    this.flights = []

    if (!destinationId) {
      return
    }

    // Show loading
    this.loadingIndicatorTarget.classList.remove("hidden")

    try {
      const response = await fetch(`/api/bode/flights?destination_id=${destinationId}`)

      if (!response.ok) {
        throw new Error("Failed to fetch flights")
      }

      this.flights = await response.json()
      this.populateFlightSelect()
    } catch (error) {
      console.error("Error fetching flights:", error)
      this.flightSelectTarget.innerHTML = '<option value="">Error loading flights</option>'
    } finally {
      this.loadingIndicatorTarget.classList.add("hidden")
    }
  }

  populateFlightSelect() {
    this.flightSelectTarget.innerHTML = '<option value="">Select a flight</option>'

    const destinationId = this.destinationSelectTarget.value
    const savedForDestination = this.savedSearchesValue[destinationId] || []

    this.flights.forEach((flight, index) => {
      // Skip flights that are already saved
      const isAlreadySaved = savedForDestination.some(
        saved => saved.date_out === flight.date_out && saved.date_in === flight.date_in
      )

      if (!isAlreadySaved) {
        const option = document.createElement("option")
        option.value = index
        option.textContent = flight.label
        this.flightSelectTarget.appendChild(option)
      }
    })
  }

  flightChanged() {
    const selectedIndex = this.flightSelectTarget.value

    if (selectedIndex === "") {
      this.dateOutTarget.value = ""
      this.dateInTarget.value = ""
      this.tripInfoTarget.textContent = "\u00A0"
      this.submitButtonTarget.disabled = true
      return
    }

    const flight = this.flights[parseInt(selectedIndex)]

    if (flight) {
      this.dateOutTarget.value = flight.date_out
      this.dateInTarget.value = flight.date_in
      this.tripInfoTarget.textContent = `${flight.nights} nights, ${flight.price}€`
      this.submitButtonTarget.disabled = false
    }
  }
}
