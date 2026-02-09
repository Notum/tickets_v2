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
    "monthFilterOut",
    "monthFilterIn"
  ]

  static values = {
    savedSearches: Object,
    selectedDestination: String
  }

  connect() {
    this.outboundDates = []
    this.inboundDates = []
    this.selectedMonthOut = null
    this.selectedMonthIn = null

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
    this.clearMonthFilter(this.hasMonthFilterOutTarget ? this.monthFilterOutTarget : null)
    this.clearMonthFilter(this.hasMonthFilterInTarget ? this.monthFilterInTarget : null)
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

    try {
      const response = await fetch(`/api/ryanair/dates_out?destination_code=${destinationCode}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        this.outboundDates = data.dates
        this.selectedMonthOut = null
        this.renderMonthFilter(data.dates, this.monthFilterOutTarget, "out")
        this.populateDateSelect(this.dateOutSelectTarget, data.dates, "out")
        this.dateOutContainerTarget.classList.remove("hidden")
        this.dateInContainerTarget.classList.add("hidden")
        this.submitButtonTarget.disabled = true
        this.selectedMonthIn = null
        this.clearMonthFilter(this.monthFilterInTarget)
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
      this.selectedMonthIn = null
      this.clearMonthFilter(this.monthFilterInTarget)
      return
    }

    this.showLoading()

    try {
      const response = await fetch(`/api/ryanair/dates_in?destination_code=${destinationCode}&date_out=${dateOut}`)
      const data = await response.json()

      if (data.dates && data.dates.length > 0) {
        // Filter dates to only show those after date_out
        let filteredDates = data.dates.filter(d => d > dateOut)

        // Filter out already saved date_in values for this destination + date_out
        const savedForDestination = this.savedSearchesValue[destinationCode] || {}
        const savedDatesIn = savedForDestination[dateOut] || []
        filteredDates = filteredDates.filter(d => !savedDatesIn.includes(d))

        if (filteredDates.length > 0) {
          this.inboundDates = filteredDates
          this.selectedMonthIn = null
          this.renderMonthFilter(filteredDates, this.monthFilterInTarget, "in")
          this.populateDateSelect(this.dateInSelectTarget, filteredDates, "in")
          this.dateInContainerTarget.classList.remove("hidden")
          this.submitButtonTarget.disabled = true
        } else {
          alert("All available return dates for this outbound flight are already saved")
          this.dateInContainerTarget.classList.add("hidden")
          this.submitButtonTarget.disabled = true
        }
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

  populateDateSelect(selectElement, dates, type) {
    selectElement.innerHTML = '<option value="">Select a date</option>'

    const selectedMonth = type === "out" ? this.selectedMonthOut : this.selectedMonthIn
    const dateOut = type === "in" ? this.dateOutSelectTarget.value : null

    dates.forEach(dateStr => {
      // Apply month filter
      if (selectedMonth) {
        const d = new Date(dateStr)
        const monthKey = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`
        if (monthKey !== selectedMonth) return
      }

      const date = new Date(dateStr)
      const option = document.createElement("option")
      option.value = dateStr

      let label = this.formatDate(date)
      if (type === "in" && dateOut) {
        const diffDays = Math.ceil(Math.abs(new Date(dateStr) - new Date(dateOut)) / (1000 * 60 * 60 * 24))
        label += ` (${diffDays}d)`
      }

      option.textContent = label
      selectElement.appendChild(option)
    })
  }

  renderMonthFilter(dates, filterTarget, type) {
    this.clearMonthFilter(filterTarget)

    const months = new Map()
    dates.forEach(dateStr => {
      const date = new Date(dateStr)
      const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`
      if (!months.has(key)) {
        const label = date.toLocaleDateString("en-US", { month: "short", year: "numeric" })
        months.set(key, label)
      }
    })

    if (months.size <= 1) return

    const allPill = this.createPill("All", null, true, type)
    filterTarget.appendChild(allPill)

    months.forEach((label, key) => {
      const pill = this.createPill(label, key, false, type)
      filterTarget.appendChild(pill)
    })
  }

  createPill(label, monthKey, isActive, type) {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.textContent = label
    btn.dataset.monthKey = monthKey || ""
    btn.className = isActive
      ? "btn btn-xs btn-primary"
      : "btn btn-xs btn-ghost"
    btn.addEventListener("click", () => this.filterByMonth(monthKey, btn, type))
    return btn
  }

  filterByMonth(monthKey, clickedBtn, type) {
    const filterTarget = type === "out" ? this.monthFilterOutTarget : this.monthFilterInTarget

    if (type === "out") {
      this.selectedMonthOut = monthKey
    } else {
      this.selectedMonthIn = monthKey
    }

    filterTarget.querySelectorAll("button").forEach(btn => {
      btn.className = btn === clickedBtn ? "btn btn-xs btn-primary" : "btn btn-xs btn-ghost"
    })

    if (type === "out") {
      this.populateDateSelect(this.dateOutSelectTarget, this.outboundDates, "out")
    } else {
      this.populateDateSelect(this.dateInSelectTarget, this.inboundDates, "in")
    }
  }

  clearMonthFilter(target) {
    if (target) {
      target.innerHTML = ""
    }
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
