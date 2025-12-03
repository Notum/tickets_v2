class SyncRyanairRoutesJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncRyanairRoutesJob] Starting Ryanair routes sync..."

    result = Ryanair::RoutesSyncService.new.call

    if result[:success]
      Rails.logger.info "[SyncRyanairRoutesJob] Sync completed successfully: #{result[:created]} created, #{result[:updated]} updated"
    else
      Rails.logger.error "[SyncRyanairRoutesJob] Sync failed: #{result[:error]}"
    end
  end
end
