class CleanupExpiredFlightSearchesService
  FLIGHT_SEARCH_MODELS = [
    RyanairFlightSearch,
    AirbalticFlightSearch,
    NorwegianFlightSearch,
    BodeFlightSearch,
    FlydubaiFlightSearch,
    TurkishFlightSearch
  ].freeze

  def initialize
    @deleted_counts = {}
  end

  def call
    Rails.logger.info "[CleanupExpiredFlightSearchesService] Starting cleanup of expired flight searches"

    total_deleted = 0

    FLIGHT_SEARCH_MODELS.each do |model|
      count = cleanup_model(model)
      @deleted_counts[model.name] = count
      total_deleted += count
    end

    Rails.logger.info "[CleanupExpiredFlightSearchesService] Completed. Total deleted: #{total_deleted}"
    log_summary

    { success: true, total_deleted: total_deleted, details: @deleted_counts }
  end

  private

  def cleanup_model(model)
    # Delete flight searches where the outbound date is before today
    expired_searches = model.where("date_out < ?", Date.current)
    count = expired_searches.count

    if count > 0
      Rails.logger.info "[CleanupExpiredFlightSearchesService] Deleting #{count} expired #{model.name} records"
      expired_searches.destroy_all
    end

    count
  end

  def log_summary
    @deleted_counts.each do |model_name, count|
      next if count.zero?
      Rails.logger.info "[CleanupExpiredFlightSearchesService] #{model_name}: #{count} deleted"
    end
  end
end
