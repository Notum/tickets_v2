import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "destinationInput",
    "destinationCode",
    "destinationName",
    "destinationCityCode",
    "destinationCountryCode",
    "destinationDropdown",
    "dateOutInput",
    "dateInInput",
    "tripDuration",
    "submitButton",
    "loadingIndicator",
    "noFlightsMessage"
  ]

  static values = {
    savedSearches: Object
  }

  connect() {
    this.selectedDestination = null
    this.searchTimeout = null
    this.highlightedIndex = -1

    // Close dropdown when clicking outside
    document.addEventListener('click', this.handleClickOutside.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside.bind(this))
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDestinationDropdown()
    }
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

  // Destination search with debounce
  searchDestinations(event) {
    const query = event.target.value.trim()

    // Clear previous timeout
    if (this.searchTimeout) {
      clearTimeout(this.searchTimeout)
    }

    if (query.length < 2) {
      this.hideDestinationDropdown()
      return
    }

    // Debounce search
    this.searchTimeout = setTimeout(async () => {
      this.showLoading()
      this.hideNoFlightsMessage()

      try {
        const response = await fetch(`/api/turkish/destinations?query=${encodeURIComponent(query)}`)
        const data = await response.json()

        if (data.destinations && data.destinations.length > 0) {
          this.showDestinationDropdown(data.destinations)
        } else {
          this.hideDestinationDropdown()
          this.showNoFlightsMessage("No destinations found for this search.")
        }
      } catch (error) {
        console.error("Error searching destinations:", error)
        this.showNoFlightsMessage("Failed to search destinations. Please try again.")
      } finally {
        this.hideLoading()
      }
    }, 300)
  }

  showDestinationDropdown(destinations) {
    const dropdown = this.destinationDropdownTarget
    dropdown.innerHTML = ""
    this.highlightedIndex = -1

    destinations.forEach((dest, index) => {
      const item = document.createElement("div")
      item.className = "px-4 py-2 cursor-pointer hover:bg-base-200 transition-colors"
      item.dataset.index = index
      item.dataset.code = dest.code
      item.dataset.name = dest.name
      item.dataset.cityCode = dest.city_code || dest.code
      item.dataset.countryCode = dest.country_code || ""
      item.textContent = dest.display_name
      item.addEventListener("click", () => this.selectDestination(dest))
      dropdown.appendChild(item)
    })

    dropdown.classList.remove("hidden")
  }

  hideDestinationDropdown() {
    if (this.hasDestinationDropdownTarget) {
      this.destinationDropdownTarget.classList.add("hidden")
    }
    this.highlightedIndex = -1
  }

  handleKeydown(event) {
    const dropdown = this.destinationDropdownTarget
    if (dropdown.classList.contains("hidden")) return

    const items = dropdown.querySelectorAll("[data-index]")
    if (items.length === 0) return

    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.highlightedIndex = Math.min(this.highlightedIndex + 1, items.length - 1)
        this.updateHighlight(items)
        break
      case "ArrowUp":
        event.preventDefault()
        this.highlightedIndex = Math.max(this.highlightedIndex - 1, 0)
        this.updateHighlight(items)
        break
      case "Enter":
        event.preventDefault()
        if (this.highlightedIndex >= 0 && items[this.highlightedIndex]) {
          items[this.highlightedIndex].click()
        }
        break
      case "Escape":
        this.hideDestinationDropdown()
        break
    }
  }

  updateHighlight(items) {
    items.forEach((item, index) => {
      if (index === this.highlightedIndex) {
        item.classList.add("bg-base-200")
      } else {
        item.classList.remove("bg-base-200")
      }
    })
  }

  selectDestination(dest) {
    this.selectedDestination = dest
    this.destinationInputTarget.value = dest.display_name
    this.destinationCodeTarget.value = dest.code
    this.destinationNameTarget.value = dest.name
    this.destinationCityCodeTarget.value = dest.city_code || dest.code
    this.destinationCountryCodeTarget.value = dest.country_code || ""

    this.hideDestinationDropdown()
    this.hideNoFlightsMessage()

    // Enable date inputs
    this.dateOutInputTarget.disabled = false
    this.dateInInputTarget.disabled = true
    this.submitButtonTarget.disabled = true

    // Clear dates
    this.dateOutInputTarget.value = ""
    this.dateInInputTarget.value = ""
    if (this.hasTripDurationTarget) {
      this.tripDurationTarget.textContent = ""
    }
  }

  dateOutChanged(event) {
    const dateOut = event.target.value

    if (!dateOut) {
      this.dateInInputTarget.disabled = true
      this.dateInInputTarget.value = ""
      this.submitButtonTarget.disabled = true
      if (this.hasTripDurationTarget) {
        this.tripDurationTarget.textContent = ""
      }
      return
    }

    this.hideNoFlightsMessage()

    // Set min date for return (day after outbound)
    const outDate = new Date(dateOut)
    const minReturn = new Date(outDate)
    minReturn.setDate(minReturn.getDate() + 1)

    // Max return date (355 days from today like Turkish Airlines)
    const maxReturn = new Date()
    maxReturn.setDate(maxReturn.getDate() + 355)

    this.dateInInputTarget.min = minReturn.toISOString().split('T')[0]
    this.dateInInputTarget.max = maxReturn.toISOString().split('T')[0]
    this.dateInInputTarget.disabled = false
    this.dateInInputTarget.value = ""
    this.submitButtonTarget.disabled = true
  }

  dateInChanged(event) {
    const dateIn = event.target.value
    const dateOut = this.dateOutInputTarget.value

    if (dateIn && dateOut && this.selectedDestination) {
      // Check if this search already exists
      const destCode = this.selectedDestination.code
      const savedKey = `${destCode}_${dateOut}`
      const savedDatesIn = this.savedSearchesValue[savedKey] || []

      if (savedDatesIn.includes(dateIn)) {
        this.showNoFlightsMessage("This flight search is already saved.")
        this.submitButtonTarget.disabled = true
        return
      }

      this.submitButtonTarget.disabled = false
      this.updateTripDuration(dateOut, dateIn)
    } else {
      this.submitButtonTarget.disabled = true
      if (this.hasTripDurationTarget) {
        this.tripDurationTarget.textContent = ""
      }
    }
  }

  updateTripDuration(dateOut, dateIn) {
    if (!this.hasTripDurationTarget) return

    const start = new Date(dateOut)
    const end = new Date(dateIn)
    const diffTime = Math.abs(end - start)
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

    this.tripDurationTarget.textContent = `Trip duration: ${diffDays} day${diffDays !== 1 ? 's' : ''}`
  }
}
