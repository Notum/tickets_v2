class SyncSsRegionsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[SyncSsRegionsJob] Starting SS.COM regions sync"

    result = Sscom::RegionsSyncService.new.call

    if result[:success]
      Rails.logger.info "[SyncSsRegionsJob] Sync complete. Created: #{result[:created_regions]} regions, #{result[:created_cities]} cities. Updated: #{result[:updated_regions]} regions, #{result[:updated_cities]} cities."
    else
      Rails.logger.error "[SyncSsRegionsJob] Sync failed: #{result[:error]}"
    end
  end
end
