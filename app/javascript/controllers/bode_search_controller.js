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

  connect() {
    this.flights = []
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

    this.flights.forEach((flight, index) => {
      const option = document.createElement("option")
      option.value = index
      option.textContent = flight.label
      this.flightSelectTarget.appendChild(option)
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
