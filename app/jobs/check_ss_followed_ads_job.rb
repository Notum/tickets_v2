class CheckSsFollowedAdsJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "[CheckSsFollowedAdsJob] Starting price check for followed SS.COM ads"

    flat_price_drops = check_flat_follows
    house_price_drops = check_house_follows

    # Send notifications
    send_price_drop_notifications(flat_price_drops, house_price_drops)

    total_checks = flat_price_drops.values.sum(&:count) + house_price_drops.values.sum(&:count)
    Rails.logger.info "[CheckSsFollowedAdsJob] Completed price check. Total price drops: #{total_checks}"
  end

  private

  def check_flat_follows
    price_drops_by_user = Hash.new { |h, k| h[k] = [] }
    removed_ads_by_user = Hash.new { |h, k| h[k] = [] }

    SsFlatFollow.active.includes(:ss_flat_ad, :user).find_each do |follow|
      ad = follow.ss_flat_ad
      user = follow.user

      result = Sscom::PriceCheckService.new(ad: ad).call

      if result[:success]
        if result[:ad_removed]
          follow.mark_as_removed!
          removed_ads_by_user[user.id] << {
            ad_type: "flat",
            title: ad.display_title,
            location: ad.location_display,
            url: ad.original_url
          }
          Rails.logger.info "[CheckSsFollowedAdsJob] Flat ad #{ad.external_id} marked as removed"
        elsif result[:price_drop].present?
          savings = result[:price_drop][:savings]
          # SS.COM doesn't have threshold like flights, notify on any drop
          price_drops_by_user[user.id] << {
            ad_type: "flat",
            title: ad.display_title,
            location: ad.location_display,
            rooms: ad.rooms,
            area: ad.area,
            floor: ad.floor_display,
            savings: savings,
            previous_price: result[:price_drop][:previous_price],
            current_price: result[:price_drop][:current_price],
            percentage: result[:price_drop][:percentage],
            url: ad.original_url
          }
          Rails.logger.info "[CheckSsFollowedAdsJob] Flat price drop detected: -€#{savings}"
        end

        follow.update!(last_checked_at: Time.current)
      else
        Rails.logger.warn "[CheckSsFollowedAdsJob] Failed to check flat ad #{ad.external_id}: #{result[:error]}"
      end

      sleep(1) # Rate limiting
    end

    # Send removed ad notifications
    removed_ads_by_user.each do |user_id, ads|
      next if ads.empty?
      user = User.find(user_id)
      SsAdRemovedMailer.ads_removed(user, ads).deliver_later
    end

    price_drops_by_user
  end

  def check_house_follows
    price_drops_by_user = Hash.new { |h, k| h[k] = [] }
    removed_ads_by_user = Hash.new { |h, k| h[k] = [] }

    SsHouseFollow.active.includes(:ss_house_ad, :user).find_each do |follow|
      ad = follow.ss_house_ad
      user = follow.user

      result = Sscom::PriceCheckService.new(ad: ad).call

      if result[:success]
        if result[:ad_removed]
          follow.mark_as_removed!
          removed_ads_by_user[user.id] << {
            ad_type: "house",
            title: ad.display_title,
            location: ad.location_display,
            url: ad.original_url
          }
          Rails.logger.info "[CheckSsFollowedAdsJob] House ad #{ad.external_id} marked as removed"
        elsif result[:price_drop].present?
          savings = result[:price_drop][:savings]
          price_drops_by_user[user.id] << {
            ad_type: "house",
            title: ad.display_title,
            location: ad.location_display,
            rooms: ad.rooms,
            area: ad.area,
            land_area: ad.land_area,
            savings: savings,
            previous_price: result[:price_drop][:previous_price],
            current_price: result[:price_drop][:current_price],
            percentage: result[:price_drop][:percentage],
            url: ad.original_url
          }
          Rails.logger.info "[CheckSsFollowedAdsJob] House price drop detected: -€#{savings}"
        end

        follow.update!(last_checked_at: Time.current)
      else
        Rails.logger.warn "[CheckSsFollowedAdsJob] Failed to check house ad #{ad.external_id}: #{result[:error]}"
      end

      sleep(1) # Rate limiting
    end

    # Send removed ad notifications
    removed_ads_by_user.each do |user_id, ads|
      next if ads.empty?
      user = User.find(user_id)
      SsAdRemovedMailer.ads_removed(user, ads).deliver_later
    end

    price_drops_by_user
  end

  def send_price_drop_notifications(flat_drops, house_drops)
    # Combine drops by user
    all_users = (flat_drops.keys + house_drops.keys).uniq

    all_users.each do |user_id|
      drops = (flat_drops[user_id] || []) + (house_drops[user_id] || [])
      next if drops.empty?

      user = User.find(user_id)
      Rails.logger.info "[CheckSsFollowedAdsJob] Sending price drop notification to #{user.email} with #{drops.count} drops"
      SsPriceDropMailer.price_dropped(user, drops).deliver_later
    end
  end
end
