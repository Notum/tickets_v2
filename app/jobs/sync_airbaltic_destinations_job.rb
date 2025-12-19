class SyncAirbalticDestinationsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncAirbalticDestinationsJob] Starting destination sync"
    result = Airbaltic::DestinationsSyncService.new.call

    if result[:success]
      Rails.logger.info "[SyncAirbalticDestinationsJob] Sync completed: #{result[:created]} created, #{result[:updated]} updated, #{result[:deactivated]} deactivated"
    else
      Rails.logger.error "[SyncAirbalticDestinationsJob] Sync failed: #{result[:error]}"
    end
  end
end
