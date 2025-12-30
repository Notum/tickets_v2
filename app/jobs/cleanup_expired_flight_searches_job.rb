class CleanupExpiredFlightSearchesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CleanupExpiredFlightSearchesJob] Starting expired flight searches cleanup"

    result = CleanupExpiredFlightSearchesService.new.call

    if result[:success]
      Rails.logger.info "[CleanupExpiredFlightSearchesJob] Cleanup completed. Deleted #{result[:total_deleted]} expired flight searches"
    else
      Rails.logger.error "[CleanupExpiredFlightSearchesJob] Cleanup failed: #{result[:error]}"
    end
  end
end
