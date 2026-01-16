class SyncNorwegianDestinationsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncNorwegianDestinationsJob] Starting Norwegian destinations sync..."

    result = Norwegian::DestinationsSyncService.new.call

    if result[:success]
      Rails.logger.info "[SyncNorwegianDestinationsJob] Sync completed successfully"
      # Note: dates are prefetched weekly by PrefetchNorwegianDatesJob on its own schedule
    else
      Rails.logger.error "[SyncNorwegianDestinationsJob] Sync failed: #{result[:error]}"
    end

    result
  end
end
