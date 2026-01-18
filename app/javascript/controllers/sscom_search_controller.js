import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "regionSelect",
    "citySelect",
    "searchButton",
    "loadingSpinner"
  ]

  static values = {
    type: String // "flats" or "houses"
  }

  connect() {
    // Initialize city select as disabled if no region selected
    if (this.hasCitySelectTarget && this.hasRegionSelectTarget) {
      if (!this.regionSelectTarget.value) {
        this.citySelectTarget.disabled = true
      }
    }

    // Listen for form submission to show loading
    if (this.hasFormTarget) {
      this.formTarget.addEventListener('submit', this.handleFormSubmit.bind(this))
      this.formTarget.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
    }
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener('submit', this.handleFormSubmit.bind(this))
      this.formTarget.removeEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
    }
  }

  async regionChanged() {
    const regionId = this.regionSelectTarget.value

    if (!regionId) {
      this.citySelectTarget.innerHTML = '<option value="">All cities</option>'
      this.citySelectTarget.disabled = true
      return
    }

    // Fetch cities for selected region
    try {
      this.citySelectTarget.disabled = true
      this.citySelectTarget.innerHTML = '<option value="">Loading...</option>'

      const response = await fetch(`/api/sscom/cities?region_id=${regionId}`)
      const data = await response.json()

      if (data.success && data.cities) {
        this.populateCities(data.cities)
      } else {
        console.error('Failed to fetch cities:', data.error)
        this.citySelectTarget.innerHTML = '<option value="">All cities</option>'
      }
    } catch (error) {
      console.error('Error fetching cities:', error)
      this.citySelectTarget.innerHTML = '<option value="">All cities</option>'
    } finally {
      this.citySelectTarget.disabled = false
    }
  }

  populateCities(cities) {
    this.citySelectTarget.innerHTML = '<option value="">All cities</option>'

    cities.forEach(city => {
      const option = document.createElement('option')
      option.value = city.id
      option.textContent = city.name_lv
      option.dataset.slug = city.slug
      this.citySelectTarget.appendChild(option)
    })
  }

  handleFormSubmit(event) {
    // Validate region is selected
    if (this.hasRegionSelectTarget && !this.regionSelectTarget.value) {
      event.preventDefault()
      alert('Please select a region')
      return
    }

    // Show loading state
    this.showLoading()
  }

  handleSubmitEnd() {
    // Hide loading state when Turbo response completes
    this.hideLoading()
  }

  showLoading() {
    if (this.hasSearchButtonTarget) {
      this.searchButtonTarget.disabled = true
    }
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.remove('hidden')
    }
  }

  hideLoading() {
    if (this.hasSearchButtonTarget) {
      this.searchButtonTarget.disabled = false
    }
    if (this.hasLoadingSpinnerTarget) {
      this.loadingSpinnerTarget.classList.add('hidden')
    }
  }
}
