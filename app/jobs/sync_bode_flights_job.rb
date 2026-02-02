class SyncBodeFlightsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncBodeFlightsJob] Starting flights sync"
    result = Bode::FlightsSyncService.new.call

    if result[:success]
      Rails.logger.info "[SyncBodeFlightsJob] Sync completed: #{result[:flights]} flights (#{result[:created]} new, #{result[:updated]} updated)"
    else
      Rails.logger.error "[SyncBodeFlightsJob] Sync failed: #{result[:error]}"
    end
  end
end
