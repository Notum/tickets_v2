class SyncNorwegianDestinationsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncNorwegianDestinationsJob] Starting Norwegian destinations sync..."

    result = Norwegian::DestinationsSyncService.new.call

    if result[:success]
      Rails.logger.info "[SyncNorwegianDestinationsJob] Sync completed successfully"

      # Prefetch dates for all destinations so users get instant responses
      Rails.logger.info "[SyncNorwegianDestinationsJob] Triggering dates prefetch job..."
      PrefetchNorwegianDatesJob.perform_later
    else
      Rails.logger.error "[SyncNorwegianDestinationsJob] Sync failed: #{result[:error]}"
    end

    result
  end
end
