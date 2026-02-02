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
    "loadingIndicator",
    "monthFilter",
    "bodeFlightId"
  ]

  static values = {
    savedSearches: Object,
    selectedDestination: String
  }

  connect() {
    this.flights = []
    this.selectedMonth = null

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
    this.bodeFlightIdTarget.value = ""
    this.tripInfoTarget.textContent = "\u00A0"
    this.submitButtonTarget.disabled = true
    this.flights = []
    this.selectedMonth = null
    this.clearMonthFilter()

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
      this.renderMonthFilter()
      this.populateFlightSelect()
    } catch (error) {
      console.error("Error fetching flights:", error)
      this.flightSelectTarget.innerHTML = '<option value="">Error loading flights</option>'
    } finally {
      this.loadingIndicatorTarget.classList.add("hidden")
    }
  }

  renderMonthFilter() {
    this.clearMonthFilter()

    // Extract unique months from flights
    const months = new Map()
    const destinationId = this.destinationSelectTarget.value
    const savedForDestination = this.savedSearchesValue[destinationId] || []

    this.flights.forEach(flight => {
      const isAlreadySaved = savedForDestination.some(
        saved => saved.date_out === flight.date_out && saved.date_in === flight.date_in
      )
      if (isAlreadySaved) return

      const date = new Date(flight.date_out_iso)
      const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`
      if (!months.has(key)) {
        const label = date.toLocaleDateString("en-US", { month: "short", year: "numeric" })
        months.set(key, label)
      }
    })

    // Only show filter if flights span multiple months
    if (months.size <= 1) return

    // "All" pill
    const allPill = this.createPill("All", null, true)
    this.monthFilterTarget.appendChild(allPill)

    months.forEach((label, key) => {
      const pill = this.createPill(label, key, false)
      this.monthFilterTarget.appendChild(pill)
    })
  }

  createPill(label, monthKey, isActive) {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.textContent = label
    btn.dataset.monthKey = monthKey || ""
    btn.className = isActive
      ? "btn btn-xs btn-primary"
      : "btn btn-xs btn-ghost"
    btn.addEventListener("click", () => this.filterByMonth(monthKey, btn))
    return btn
  }

  filterByMonth(monthKey, clickedBtn) {
    this.selectedMonth = monthKey

    // Update pill styles
    this.monthFilterTarget.querySelectorAll("button").forEach(btn => {
      if (btn === clickedBtn) {
        btn.className = "btn btn-xs btn-primary"
      } else {
        btn.className = "btn btn-xs btn-ghost"
      }
    })

    this.populateFlightSelect()
  }

  clearMonthFilter() {
    if (this.hasMonthFilterTarget) {
      this.monthFilterTarget.innerHTML = ""
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
      if (isAlreadySaved) return

      // Filter by selected month
      if (this.selectedMonth) {
        const date = new Date(flight.date_out_iso)
        const flightMonth = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`
        if (flightMonth !== this.selectedMonth) return
      }

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
      this.bodeFlightIdTarget.value = ""
      this.tripInfoTarget.textContent = "\u00A0"
      this.submitButtonTarget.disabled = true
      return
    }

    const flight = this.flights[parseInt(selectedIndex)]

    if (flight) {
      this.dateOutTarget.value = flight.date_out
      this.dateInTarget.value = flight.date_in
      this.bodeFlightIdTarget.value = flight.id || ""
      this.tripInfoTarget.textContent = `${flight.nights} nights, ${flight.price}€`
      this.submitButtonTarget.disabled = false
    }
  }
}
