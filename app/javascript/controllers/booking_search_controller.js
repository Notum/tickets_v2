import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "cityInput",
    "hotelNameInput",
    "checkInInput",
    "checkOutInput",
    "stayDuration",
    "searchButton",
    "submitButton",
    "loadingIndicator",
    "hotelResults",
    "hotelList",
    "hotelIdInput",
    "hotelNameHiddenInput",
    "hotelUrlInput",
    "countryNameInput",
    "roomResults",
    "roomList",
    "roomIdInput",
    "blockIdInput",
    "roomNameInput",
    "roomLoading"
  ]

  static values = {
    savedSearches: Object,
    currency: String
  }

  connect() {
    this.selectedHotel = null
    this.selectedRoom = null
    this.submitButtonTarget.disabled = true
    // Ensure checkout is disabled on load
    this.checkOutInputTarget.disabled = true
  }

  cityChanged() {
    this.clearHotelSelection()
  }

  checkInChanged() {
    const checkIn = this.checkInInputTarget.value

    if (checkIn) {
      // Enable checkout and set min date to day after check-in
      const checkInDate = new Date(checkIn)
      const minCheckOut = new Date(checkInDate)
      minCheckOut.setDate(minCheckOut.getDate() + 1)

      this.checkOutInputTarget.disabled = false
      this.checkOutInputTarget.min = this.formatDate(minCheckOut)

      // If checkout is before new min date, clear it
      if (this.checkOutInputTarget.value && this.checkOutInputTarget.value <= checkIn) {
        this.checkOutInputTarget.value = ''
        this.stayDurationTarget.textContent = ''
      } else {
        this.updateStayDuration()
      }
    } else {
      // Disable checkout if no check-in
      this.checkOutInputTarget.disabled = true
      this.checkOutInputTarget.value = ''
      this.stayDurationTarget.textContent = ''
    }

    this.clearHotelSelection()
  }

  checkOutChanged() {
    this.updateStayDuration()
    this.clearHotelSelection()
  }

  formatDate(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  }

  updateStayDuration() {
    if (!this.hasStayDurationTarget) return

    const checkIn = this.checkInInputTarget.value
    const checkOut = this.checkOutInputTarget.value

    if (checkIn && checkOut) {
      const start = new Date(checkIn)
      const end = new Date(checkOut)
      const diffTime = Math.abs(end - start)
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24))

      this.stayDurationTarget.textContent = `${diffDays} night${diffDays !== 1 ? 's' : ''}`
    } else {
      this.stayDurationTarget.textContent = ''
    }
  }

  clearHotelSelection() {
    this.selectedHotel = null
    this.selectedRoom = null
    this.submitButtonTarget.disabled = true
    this.hotelIdInputTarget.value = ''
    this.hotelNameHiddenInputTarget.value = ''
    this.hotelUrlInputTarget.value = ''
    this.countryNameInputTarget.value = ''

    if (this.hasHotelResultsTarget) {
      this.hotelResultsTarget.classList.add('hidden')
    }

    this.clearRoomSelection()
  }

  clearRoomSelection() {
    this.selectedRoom = null
    this.submitButtonTarget.disabled = true

    if (this.hasRoomIdInputTarget) {
      this.roomIdInputTarget.value = ''
    }
    if (this.hasBlockIdInputTarget) {
      this.blockIdInputTarget.value = ''
    }
    if (this.hasRoomNameInputTarget) {
      this.roomNameInputTarget.value = ''
    }
    if (this.hasRoomResultsTarget) {
      this.roomResultsTarget.classList.add('hidden')
    }
  }

  async searchHotels() {
    const city = this.cityInputTarget.value.trim()
    const hotelName = this.hotelNameInputTarget.value.trim()
    const checkIn = this.checkInInputTarget.value
    const checkOut = this.checkOutInputTarget.value

    if (!city || !hotelName || !checkIn || !checkOut) {
      alert('Please fill in all fields before searching')
      return
    }

    if (new Date(checkOut) <= new Date(checkIn)) {
      alert('Check-out date must be after check-in date')
      return
    }

    this.showLoading()
    this.clearHotelSelection()

    try {
      const params = new URLSearchParams({
        city: city,
        hotel_name: hotelName,
        check_in: checkIn,
        check_out: checkOut,
        adults: document.getElementById('adults').value,
        rooms: document.getElementById('rooms').value
      })

      const response = await fetch(`/api/booking/search_hotels?${params}`)
      const data = await response.json()

      if (data.success && data.hotels && data.hotels.length > 0) {
        this.displayHotelResults(data.hotels)
      } else if (data.success && (!data.hotels || data.hotels.length === 0)) {
        this.hotelResultsTarget.classList.remove('hidden')
        this.hotelListTarget.innerHTML = '<p class="text-base-content/70 text-sm">No hotels found. Try a different search.</p>'
      } else {
        alert(data.error || 'Failed to search hotels. Please try again.')
      }
    } catch (error) {
      console.error('Error searching hotels:', error)
      alert('Failed to search hotels. Please try again.')
    } finally {
      this.hideLoading()
    }
  }

  displayHotelResults(hotels) {
    this.hotelResultsTarget.classList.remove('hidden')
    this.hotelListTarget.innerHTML = ''

    hotels.forEach(hotel => {
      const div = document.createElement('div')
      div.className = 'bg-base-200 rounded-lg p-3 cursor-pointer hover:bg-base-300 transition-colors'
      div.dataset.action = 'click->booking-search#selectHotel'
      div.dataset.hotelId = hotel.hotel_id
      div.dataset.hotelName = hotel.name
      div.dataset.hotelUrl = hotel.url || ''
      div.dataset.hotelPrice = hotel.raw_price || ''

      let priceHtml = ''
      if (hotel.raw_price) {
        const symbol = this.currencyValue === 'USD' ? '$' : '€'
        priceHtml = `<span class="text-success font-semibold">${symbol}${hotel.raw_price.toFixed(2)}</span>`
      }

      div.innerHTML = `
        <div class="flex items-center justify-between">
          <div>
            <div class="font-medium text-sm">${this.escapeHtml(hotel.name)}</div>
            <div class="text-xs text-base-content/50">ID: ${hotel.hotel_id}</div>
          </div>
          ${priceHtml}
        </div>
      `

      this.hotelListTarget.appendChild(div)
    })
  }

  async selectHotel(event) {
    const target = event.currentTarget
    const hotelId = target.dataset.hotelId
    const hotelName = target.dataset.hotelName
    const hotelUrl = target.dataset.hotelUrl

    // Update selection styling
    this.hotelListTarget.querySelectorAll('div').forEach(el => {
      el.classList.remove('ring-2', 'ring-primary')
    })
    target.classList.add('ring-2', 'ring-primary')

    // Set hidden fields
    this.hotelIdInputTarget.value = hotelId
    this.hotelNameHiddenInputTarget.value = hotelName
    this.hotelUrlInputTarget.value = hotelUrl
    this.countryNameInputTarget.value = ''

    this.selectedHotel = { id: hotelId, name: hotelName, url: hotelUrl }

    // Clear previous room selection
    this.clearRoomSelection()

    // Fetch rooms for this hotel
    if (hotelUrl) {
      await this.fetchRooms(hotelUrl)
    } else {
      // If no URL available, allow direct submission without room selection
      this.submitButtonTarget.disabled = false
    }
  }

  async fetchRooms(hotelUrl) {
    const checkIn = this.checkInInputTarget.value
    const checkOut = this.checkOutInputTarget.value
    const adults = document.getElementById('adults').value
    const rooms = document.getElementById('rooms').value

    this.showRoomLoading()

    try {
      const params = new URLSearchParams({
        hotel_url: hotelUrl,
        check_in: checkIn,
        check_out: checkOut,
        adults: adults,
        rooms: rooms
      })

      const response = await fetch(`/api/booking/fetch_rooms?${params}`)
      const data = await response.json()

      if (data.success && data.rooms && data.rooms.length > 0) {
        this.displayRoomResults(data.rooms)
      } else if (data.success && (!data.rooms || data.rooms.length === 0)) {
        this.roomResultsTarget.classList.remove('hidden')
        this.roomListTarget.innerHTML = '<p class="text-base-content/70 text-sm">No rooms found. The hotel may be sold out.</p>'
      } else {
        console.error('Room fetch error:', data.error)
        this.roomResultsTarget.classList.remove('hidden')
        this.roomListTarget.innerHTML = `<p class="text-error text-sm">${data.error || 'Failed to fetch rooms. Please try again.'}</p>`
      }
    } catch (error) {
      console.error('Error fetching rooms:', error)
      this.roomResultsTarget.classList.remove('hidden')
      this.roomListTarget.innerHTML = '<p class="text-error text-sm">Failed to fetch rooms. Please try again.</p>'
    } finally {
      this.hideRoomLoading()
    }
  }

  displayRoomResults(rooms) {
    this.roomResultsTarget.classList.remove('hidden')
    this.roomListTarget.innerHTML = ''

    const symbol = this.currencyValue === 'USD' ? '$' : '€'

    rooms.forEach(room => {
      const div = document.createElement('div')
      div.className = 'bg-base-200 rounded-lg p-3 cursor-pointer hover:bg-base-300 transition-colors'
      div.dataset.action = 'click->booking-search#selectRoom'
      div.dataset.roomId = room.room_id
      div.dataset.blockId = room.block_id || ''
      div.dataset.roomName = room.name
      div.dataset.roomPrice = room.price

      let perNightHtml = ''
      if (room.price_per_night) {
        perNightHtml = `<span class="text-xs text-base-content/50">${symbol}${room.price_per_night.toFixed(2)}/night</span>`
      }

      div.innerHTML = `
        <div class="flex items-center justify-between">
          <div class="flex-1 min-w-0">
            <div class="font-medium text-sm truncate">${this.escapeHtml(room.name)}</div>
            ${perNightHtml}
          </div>
          <div class="text-right shrink-0 ml-3">
            <span class="text-success font-semibold">${symbol}${room.price.toFixed(2)}</span>
          </div>
        </div>
      `

      this.roomListTarget.appendChild(div)
    })
  }

  selectRoom(event) {
    const target = event.currentTarget
    const roomId = target.dataset.roomId
    const blockId = target.dataset.blockId
    const roomName = target.dataset.roomName

    // Check if already tracking this hotel+room for these dates
    const hotelId = this.hotelIdInputTarget.value
    const checkIn = this.checkInInputTarget.value
    const checkOut = this.checkOutInputTarget.value
    const searchKey = `${hotelId}_${roomId}_${checkIn}_${checkOut}`

    if (this.savedSearchesValue[searchKey]) {
      alert('You are already tracking this room for these dates.')
      return
    }

    // Update selection styling
    this.roomListTarget.querySelectorAll('div').forEach(el => {
      el.classList.remove('ring-2', 'ring-primary')
    })
    target.classList.add('ring-2', 'ring-primary')

    // Set hidden fields
    this.roomIdInputTarget.value = roomId
    this.blockIdInputTarget.value = blockId
    this.roomNameInputTarget.value = roomName

    this.selectedRoom = { id: roomId, blockId: blockId, name: roomName }
    this.submitButtonTarget.disabled = false
  }

  showLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.remove('hidden')
    }
    this.searchButtonTarget.disabled = true
  }

  hideLoading() {
    if (this.hasLoadingIndicatorTarget) {
      this.loadingIndicatorTarget.classList.add('hidden')
    }
    this.searchButtonTarget.disabled = false
  }

  showRoomLoading() {
    if (this.hasRoomLoadingTarget) {
      this.roomLoadingTarget.classList.remove('hidden')
    }
    if (this.hasRoomResultsTarget) {
      this.roomResultsTarget.classList.add('hidden')
    }
  }

  hideRoomLoading() {
    if (this.hasRoomLoadingTarget) {
      this.roomLoadingTarget.classList.add('hidden')
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
