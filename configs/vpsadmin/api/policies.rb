policy :unpaid_cpu do
  label 'VPS CPU time of unpaid users'
  desc 'The VPS used more than 50% CPU for the last 30 minutes'
  period 30*60
  cooldown 10*60

  query do
    ::Vps.joins(
        :vps_current_status, user: :user_account
    ).includes(
        :vps_current_status
    ).where(
        users: {object_state: ::User.object_states[:active]},
        user_accounts: {paid_until: nil},
        vpses: {object_state: ::Vps.object_states[:active]},
        vps_current_statuses: {status: true},
    )
  end

  value { |vps| vps.vps_current_status.cpu_idle }
  check { |vps, v| v.nil? || vps.cpu <= 2 || v >= 50 }
end

policy :unpaid_data_flow do
  label 'Public IP traffic of unpaid users'
  desc 'Data transfer rate was faster than 200 Mbps for the last 30 minutes'
  period 30*60

  query do
    ::IpTrafficLiveMonitor.select(
        "#{::IpTrafficLiveMonitor.table_name}.*, SUM(public_bytes_out) AS bytes_all"
    ).joins(
        ip_address: {vps: [:vps_current_status, user: :user_account]}
    ).where(
        users: {object_state: ::User.object_states[:active]},
        user_accounts: {paid_until: nil},
        vpses: {object_state: ::Vps.object_states[:active]},
        vps_current_statuses: {status: true},
    ).group('vpses.id')
  end

  object { |mon| mon.ip_address.vps }
  value { |mon| mon.bytes_all }
  check { |mon, v| (v * 8) < 200*1024*1024 }
end

policy :paid_cpu do
  label 'VPS CPU time'
  desc 'The VPS used more than 75% CPU for the last 3 days'
  period 3*24*60*60

  query do
    ::Vps.joins(:vps_current_status, user: :user_account).where(
        users: {object_state: ::User.object_states[:active]},
        vpses: {object_state: ::Vps.object_states[:active]},
        vps_current_statuses: {status: true},
    ).includes(
        :vps_current_status
    ).where.not(
        user_accounts: {paid_until: nil},
    )
  end

  value { |vps| vps.vps_current_status.cpu_idle }
  check { |vps, v| v.nil? || vps.cpu <= 4 || v > 25 }
end

policy :monthly_traffic do
  label 'Monthly traffic'
  desc "The user's monthly traffic is now more than 10 TiB"
  check_count 1
  cooldown 7*24*60*60

  query do
    ::IpTrafficMonthlySummary.joins(:user).select(
        "#{IpTrafficMonthlySummary.table_name}.*,
        (SUM(bytes_in) + SUM(bytes_out)) AS bytes_all"
    ).where(
        users: {object_state: ::User.object_states[:active]},
        role: ::IpTrafficMonthlySummary.roles[:role_public],
    ).where(
        'year = YEAR(NOW()) AND month = MONTH(NOW())'
    ).group('user_id')
  end

  object { |tr| tr.user }
  value { |tr| tr.bytes_all }
  check { |tr, v| v < 10 * 1024*1024*1024*1024 }
end
