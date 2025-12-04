class SyncBodeDestinationsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncBodeDestinationsJob] Starting destination sync"
    result = Bode::DestinationsSyncService.new.call

    if result[:success]
      Rails.logger.info "[SyncBodeDestinationsJob] Sync completed: #{result[:created]} created, #{result[:updated]} updated"
    else
      Rails.logger.error "[SyncBodeDestinationsJob] Sync failed: #{result[:error]}"
    end
  end
end
