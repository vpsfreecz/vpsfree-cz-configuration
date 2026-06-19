MailTemplate.register :alert_role_event_state,
                      name: 'alert_%{role}_%{event}_%{state}', params: {
                        role: 'user or admin',
                        event: 'name of event monitor',
                        state: 'event state'
                      }, vars: {
                        event: 'MonitoredEvent',
                        object: 'object associated with this event',
                        user: User,
                        base_url: 'URL to the web UI'
                      }, roles: %i[admin]

MailTemplate.register :alert_role_diskspace_state_pool,
                      name: 'alert_%{role}_diskspace_%{state}_%{pool}', params: {
                        role: 'user or admin',
                        state: 'event state',
                        pool: 'primary or hypervisor'
                      }, vars: {
                        event: 'MonitoredEvent',
                        dip: DatasetInPool,
                        ds: Dataset,
                        vps: '::Vps or nil',
                        user: User,
                        base_url: 'URL to the web UI'
                      }, roles: %i[admin]

MailTemplate.register :alert_user_zombie_processes_state,
                      name: 'alert_user_zombie_processes_%{state}', params: {
                        state: 'event state'
                      }, vars: {
                        event: 'MonitoredEvent',
                        vps: Vps,
                        zombie_process_count: Integer,
                        threshold: Integer,
                        user: User,
                        base_url: 'URL to the web UI'
                      }, roles: %i[admin]

MailTemplate.register :alert_user_zombie_processes_restart,
                      name: 'alert_user_zombie_processes_restart', vars: {
                        event: 'MonitoredEvent',
                        vps: Vps,
                        zombie_process_count: Integer,
                        threshold: Integer,
                        finish_weekday: Integer,
                        finish_minutes: Integer,
                        user: User,
                        base_url: 'URL to the web UI'
                      }, roles: %i[admin]

MailTemplate.register :alert_user_vps_in_rescue,
                      name: 'alert_user_vps_in_rescue', vars: {
                        event: 'MonitoredEvent',
                        vps: Vps,
                        user: User,
                        base_url: 'URL to the web UI'
                      }, roles: %i[admin]

MailTemplate.register :alert_vps_dataset_over_quota,
                      name: 'alert_vps_dataset_over_quota', vars: {
                        dataset: Dataset,
                        expansion: DatasetExpansion,
                        vps: Vps,
                        user: User,
                        base_url: 'URL to the web UI'
                      }, roles: %i[admin]

VpsAdmin::API::Plugins::Monitoring.config do
  # Action definitions
  action :alert_user do |event|
    route_monitoring_alert!(
      event,
      role: 'user',
      variant: :role_event_state
    )
  end

  action :alert_user_diskspace do |event|
    dip = event.object.primary_dataset_in_pool!
    vps = if dip.pool.role == 'hypervisor'
            Vps.find_by!(
              dataset_in_pool: dip.dataset.root.primary_dataset_in_pool!
            )
          end

    route_monitoring_alert!(
      event,
      role: 'user',
      variant: :role_diskspace_state_pool,
      context: {
        dip: dip,
        vps: vps,
        pool_role: dip.pool.role
      }
    )
  end

  action :alert_admins do |event|
    monitoring_admin_recipients.each do |admin|
      route_monitoring_alert!(
        event,
        recipient: admin,
        role: 'admin',
        variant: :role_event_state,
        context: {
          language: Language.take!
        }
      )
    end
  end

  action :alert_user_zombie_processes do |event|
    threshold = 10_000
    vps = event.object

    if vps.zombie_process_count > threshold
      # Plan restart unless one was already planned
      next if event.action_state && event.action_state['restart_planned']

      now = Time.now

      finish_weekday =
        if now.hour < 4 || (now.hour == 4 && now.min <= 30)
          now.wday
        else
          (now + (24 * 60 * 60)).wday
        end

      finish_minutes = (4 * 60) + rand(35..55) # 04:35-55

      opts = {
        finish_weekday: finish_weekday,
        finish_minutes: finish_minutes
      }

      lock(vps)

      route_monitoring_alert!(
        event,
        role: 'user',
        alert_kind: 'restart',
        variant: :zombie_processes_restart,
        context: {
          vps: vps,
          threshold: threshold,
          finish_weekday: finish_weekday,
          finish_minutes: finish_minutes
        },
        parameters: opts
      )

      append_t(
        Transactions::MaintenanceWindow::Wait,
        args: [vps, 15],
        kwargs: {
          maintenance_windows: VpsMaintenanceWindow.make_for(
            vps,
            finish_weekday: finish_weekday,
            finish_minutes: finish_minutes
          )
        }
      )

      append_t(Transactions::Vps::Restart, args: [vps])

      event.action_state ||= {}
      event.action_state['restart_planned'] = true
      event.save!

    elsif !%w[acknowledged ignored].include?(event.state)
      # Alert the user about too many zombies once per day
      last_alert =
        if event.action_state && event.action_state['last_alert']
          Time.at(event.action_state['last_alert'])
        end

      next if last_alert && last_alert + (24 * 60 * 60) > Time.now

      route_monitoring_alert!(
        event,
        role: 'user',
        variant: :zombie_processes_state,
        context: {
          vps: vps,
          threshold: threshold
        }
      )

      event.action_state ||= {}
      event.action_state['last_alert'] = Time.now.to_i
      event.save!
    end
  end

  action :alert_user_vps_in_rescue do |event|
    next if event.state == 'closed'

    route_monitoring_alert!(
      event,
      role: 'user',
      variant: :vps_in_rescue
    )
  end

  action :alert_vps_dataset_over_quota do |event|
    next if event.state == 'closed'

    route_monitoring_alert!(
      event,
      role: 'user',
      variant: :dataset_over_quota
    )
  end

  # Monitors
  ## Unpaid users
  monitor :unpaid_cpu do
    label 'VPS CPU time of unpaid users'
    desc 'The VPS used more than 200% CPU for the last 30 or more minutes'
    period 30 * 60
    repeat 10 * 60
    access_level 90

    query do
      Vps.joins(
        :vps_current_status, user: :user_account
      ).includes(
        :vps_current_status
      ).where(
        users: { object_state: User.object_states[:active] },
        user_accounts: { paid_until: nil },
        vpses: { object_state: Vps.object_states[:active] },
        vps_current_statuses: { status: true, is_running: true }
      )
    end

    value do |vps|
      (vps.cpu * 100) - (vps.vps_current_status.cpu_idle * vps.cpu)
    end
    check { |_vps, v| v.nil? || v < 200 }
    action :alert_admins
  end

  monitor :unpaid_data_flow do
    label 'IP traffic of unpaid users'
    desc 'Data transfer rate was faster than 200 Mbps for the last 30 or more minutes'
    period 30 * 60
    repeat 10 * 60
    access_level 90

    query do
      NetworkInterfaceMonitor.select(
        "#{NetworkInterfaceMonitor.table_name}.*, SUM(bytes_out / delta) AS bytes_all"
      ).joins(
        network_interface: { vps: [:vps_current_status, { user: :user_account }] }
      ).where(
        users: { object_state: User.object_states[:active] },
        user_accounts: { paid_until: nil },
        vpses: { object_state: Vps.object_states[:active] },
        vps_current_statuses: { status: true, is_running: true }
      ).group('vpses.id')
    end

    object { |mon| mon.network_interface.vps }
    value { |mon| (mon.bytes_all * 8).to_i }
    check { |_mon, v| v < 200 * 1024 * 1024 }
    action :alert_admins
  end

  ## Others
  monitor :diskspace do
    label 'Dataset free space'
    desc 'The dataset has less than 10 % of free space'
    period 60 * 60
    repeat 1 * 24 * 60 * 60
    cooldown 6 * 60 * 60

    query do
      DatasetInPool.joins(
        :pool, dataset: [:user]
      ).joins(
        'LEFT JOIN vpses ON vpses.dataset_in_pool_id = dataset_in_pools.id'
      ).includes(
        :pool, :dataset_properties, dataset: :user
      ).where(
        users: { object_state: User.object_states[:active] },
        pools: { role: [
          Pool.roles[:primary],
          Pool.roles[:hypervisor]
        ] }
      ).where(
        'vpses.id IS NULL OR vpses.object_state  = ?',
        Vps.object_states[:active]
      )
    end

    object(&:dataset)
    value do |dip|
      if dip.used && dip.used > 0
        dip.avail.to_f / (dip.pool.refquota_check ? dip.refquota : dip.dataset.effective_quota) * 100

      else
        100
      end
    end

    check { |_dip, v| v > 10 }
    user { |dip| dip.dataset.user }
    action :alert_user_diskspace
  end

  monitor :paid_cpu do
    label 'VPS CPU time'
    desc 'The VPS used more than 300% CPU for the last 3 or more days'
    period 3 * 24 * 60 * 60
    repeat 1 * 24 * 60 * 60

    query do
      Vps.joins(:vps_current_status, user: :user_account).where(
        users: { object_state: User.object_states[:active] },
        vpses: { object_state: Vps.object_states[:active] },
        vps_current_statuses: { status: true, is_running: true }
      ).includes(
        :vps_current_status
      ).where.not(
        user_accounts: { paid_until: nil }
      )
    end

    value do |vps|
      (vps.cpu * 100) - (vps.vps_current_status.cpu_idle * vps.cpu)
    end
    check { |_vps, v| v.nil? || v < 300 }
    action :alert_user
  end

  monitor :monthly_traffic do
    label 'Monthly traffic'
    desc "The user's monthly traffic is now more than 10 TiB"
    check_count 1
    repeat 7 * 24 * 60 * 60
    access_level 90

    query do
      NetworkInterfaceMonthlyAccounting.joins(:user).select(
        "#{NetworkInterfaceMonthlyAccounting.table_name}.*,
        (SUM(bytes_in) + SUM(bytes_out)) AS bytes_all"
      ).where(
        users: { object_state: User.object_states[:active] }
      ).where(
        'year = YEAR(NOW()) AND month = MONTH(NOW())'
      ).group('user_id')
    end

    object(&:user)
    value(&:bytes_all)
    check { |_tr, v| v < 30 * 1024 * 1024 * 1024 * 1024 }
    action :alert_admins
  end

  monitor :vps_zombie_processes do
    label 'Zombie processes'
    desc 'VPS has too many zombie processes'
    period 1 * 60 * 60
    repeat 1 * 60 * 60 # repeat is further controlled by the called action
    skip_acknowledged false
    skip_ignored false

    query do
      Vps
        .select('vpses.*, vps_os_processes.`count` AS zombie_process_count')
        .joins(:vps_os_processes, :vps_current_status, :user)
        .where(
          vps_os_processes: { state: 'Z' },
          vps_current_statuses: { status: true, is_running: true },
          users: { object_state: User.object_states[:active] },
          vpses: { object_state: Vps.object_states[:active] }
        )
    end

    user do |vps, _|
      vps.user
    end

    value do |vps|
      vps.zombie_process_count.to_i
    end

    check do |_vps, value|
      value < 1000
    end

    action :alert_user_zombie_processes
  end

  monitor :outgoing_data_flow do
    label 'High outgoing data flow'
    desc 'Outgoing data transfer rate was high for the last 6 or more hours'
    period 6 * 60 * 60
    repeat 6 * 60 * 60
    cooldown 1 * 60 * 60

    query do
      NetworkInterfaceMonitor.select(
        "#{NetworkInterfaceMonitor.table_name}.*, SUM(bytes_out / delta) AS bytes_out_sum"
      ).joins(
        network_interface: { vps: [:vps_current_status, { user: :user_account }] }
      ).includes(
        network_interface: { vps: { node: :location } }
      ).where(
        users: { object_state: User.object_states[:active] },
        vpses: { object_state: Vps.object_states[:active] },
        vps_current_statuses: { status: true, is_running: true }
      ).group('vpses.id')
    end

    object { |mon| mon.network_interface.vps }
    value { |mon| (mon.bytes_out_sum * 8).to_i }

    check do |mon, v|
      limit =
        case mon.network_interface.vps.node.location.label
        when 'Praha'
          800
        else
          250
        end

      v < (limit * 1024 * 1024)
    end

    action :alert_user
  end

  monitor :vps_in_rescue_mode do
    label 'VPS in rescue mode'
    desc 'VPS is in rescue mode for too long'
    check_count 1
    repeat 24 * 60 * 60

    query do
      Vps.joins(:vps_current_status, :user).where(
        users: { object_state: User.object_states[:active] },
        vpses: { object_state: Vps.object_states[:active] },
        vps_current_statuses: { status: true, is_running: true }
      ).includes(
        :vps_current_status
      )
    end

    value do |vps|
      vps.vps_current_status.uptime
    end

    check do |vps, value|
      if vps.vps_current_status.in_rescue_mode
        value < 24 * 60 * 60
      else
        true
      end
    end

    action :alert_user_vps_in_rescue
  end

  monitor :dns_secondary_transfer_failure do
    label 'DNS secondary transfer failure'
    desc 'DNS secondary zone transfer has failed'
    period 30 * 60
    repeat 24 * 60 * 60
    cooldown 60 * 60

    query do
      DnsServerZone
        .joins(dns_zone: :user)
        .includes(
          :dns_server,
          dns_zone: [:user, { dns_zone_transfers: :host_ip_address }]
        )
        .where(
          zone_type: DnsServerZone.zone_types[:secondary_type],
          dns_zones: {
            zone_source: DnsZone.zone_sources[:external_source],
            enabled: true
          },
          users: { object_state: User.object_states[:active] }
        )
    end

    value do |server_zone|
      server_zone.last_transfer_status.to_s
    end

    check do |server_zone, transfer_status|
      next true if transfer_status != 'failed'

      primary_addr = server_zone.last_transfer_primary_addr.to_s
      next true if primary_addr.empty?

      server_zone.dns_zone.dns_zone_transfers.none? do |transfer|
        transfer.primary_type? &&
          %i[confirm_create confirmed].include?(transfer.confirmed) &&
          transfer.ip_addr == primary_addr
      end
    end

    user do |server_zone, _real|
      server_zone.dns_zone.user
    end

    action :alert_user
  end

  monitor :vps_dataset_expansions do
    label 'VPS dataset over quota'
    desc 'VPS dataset is temporarily expanded'
    period 12 * 60 * 60
    repeat 24 * 60 * 60

    query do
      Dataset.includes(:user, :dataset_expansion).joins(:user, dataset_expansion: :vps).where(
        dataset_expansions: {
          state: 'active',
          enable_notifications: true
        },
        vpses: { object_state: Vps.object_states[:active] },
        users: { object_state: User.object_states[:active] }
      ).where.not(
        dataset_expansion: nil
      )
    end

    user do |ds, _|
      ds.user
    end

    value(&:refquota)

    check do |ds, _value|
      ds.referenced < ds.dataset_expansion.original_refquota
    end

    action :alert_vps_dataset_over_quota
  end
end
