monitoring_state_vars = {
  event: 'MonitoredEvent',
  object: 'object associated with this event',
  user: User,
  base_url: 'URL to the web UI'
}
monitoring_diskspace_vars = monitoring_state_vars.merge(
  dip: DatasetInPool,
  ds: Dataset,
  vps: '::Vps or nil'
)
monitoring_zombie_vars = monitoring_state_vars.merge(
  vps: Vps,
  zombie_process_count: Integer,
  threshold: Integer
)

%i[
  alert_monthly_traffic_closed
  alert_monthly_traffic_confirmed
  alert_unpaid_cpu_closed
  alert_unpaid_cpu_confirmed
  alert_unpaid_data_flow_closed
  alert_unpaid_data_flow_confirmed
  alert_paid_cpu_closed
  alert_paid_cpu_confirmed
  alert_outgoing_data_flow_closed
  alert_outgoing_data_flow_confirmed
  alert_dns_secondary_transfer_failure_closed
  alert_dns_secondary_transfer_failure_confirmed
].each do |template_name|
  NotificationTemplate.register template_name,
                                vars: monitoring_state_vars,
                                public: true
end

%i[
  alert_diskspace_closed_hypervisor
  alert_diskspace_closed_primary
  alert_diskspace_confirmed_hypervisor
  alert_diskspace_confirmed_primary
].each do |template_name|
  NotificationTemplate.register template_name,
                                vars: monitoring_diskspace_vars,
                                public: true
end

%i[
  alert_zombie_processes_closed
  alert_zombie_processes_confirmed
].each do |template_name|
  NotificationTemplate.register template_name,
                                vars: monitoring_zombie_vars,
                                public: true
end

NotificationTemplate.register :alert_zombie_processes_restart,
                              vars: monitoring_zombie_vars.merge(
                                finish_weekday: Integer,
                                finish_minutes: Integer
                              ),
                              public: true

NotificationTemplate.register :alert_vps_in_rescue,
                              vars: monitoring_state_vars.merge(vps: Vps),
                              public: true

NotificationTemplate.register :alert_vps_dataset_over_quota,
                              vars: {
                                dataset: Dataset,
                                expansion: DatasetExpansion,
                                vps: Vps,
                                user: User,
                                base_url: 'URL to the web UI'
                              },
                              public: true

monitoring_events = VpsAdmin::API::Plugins::Monitoring::Events
monitoring_state_template = lambda do |prefix|
  lambda do |event, _context|
    :"alert_#{prefix}_#{monitoring_events.template_state(event)}"
  end
end

VpsAdmin::API::Plugins::Monitoring.config do
  alert_event 'monitoring.unpaid_cpu',
              label: 'Unpaid VPS CPU usage',
              template: monitoring_state_template.call('unpaid_cpu'),
              monitors: %i[unpaid_cpu],
              fields: %i[vps]

  alert_event 'monitoring.unpaid_data_flow',
              label: 'Unpaid user data flow',
              template: monitoring_state_template.call('unpaid_data_flow'),
              monitors: %i[unpaid_data_flow],
              fields: %i[vps]

  alert_event 'monitoring.monthly_traffic',
              label: 'Monthly traffic',
              template: monitoring_state_template.call('monthly_traffic'),
              monitors: %i[monthly_traffic]

  alert_event 'monitoring.diskspace_low',
              label: 'Dataset free space',
              template: lambda { |event, context|
                pool = monitoring_events.context_value(context, :pool_role)
                :"alert_diskspace_#{monitoring_events.template_state(event)}_#{pool}"
              },
              monitors: %i[diskspace],
              fields: %i[vps dataset pool_role],
              vars: lambda { |base, event, context|
                base.merge(
                  dip: monitoring_events.context_value(context, :dip),
                  ds: event.object,
                  vps: monitoring_events.context_value(context, :vps)
                )
              }

  alert_event 'monitoring.paid_cpu',
              label: 'VPS CPU usage',
              template: monitoring_state_template.call('paid_cpu'),
              monitors: %i[paid_cpu],
              fields: %i[vps]

  alert_event 'monitoring.outgoing_data_flow',
              label: 'High outgoing data flow',
              template: monitoring_state_template.call('outgoing_data_flow'),
              monitors: %i[outgoing_data_flow],
              fields: %i[vps]

  alert_event 'monitoring.zombie_processes',
              label: 'Zombie processes',
              template: lambda { |event, _context|
                :"alert_zombie_processes_#{monitoring_events.template_state(event)}"
              },
              monitors: %i[vps_zombie_processes],
              fields: %i[vps threshold],
              vars: lambda { |base, event, context|
                vps = monitoring_events.context_value(context, :vps) || event.object
                base.merge(
                  vps:,
                  zombie_process_count: vps.zombie_process_count,
                  threshold: monitoring_events.context_value(context, :threshold)
                )
              }

  alert_event 'monitoring.zombie_processes_restart',
              label: 'Zombie processes restart planned',
              template: :alert_zombie_processes_restart,
              fields: %i[vps threshold maintenance],
              vars: lambda { |base, event, context|
                vps = monitoring_events.context_value(context, :vps) || event.object
                base.merge(
                  vps:,
                  zombie_process_count: vps.zombie_process_count,
                  threshold: monitoring_events.context_value(context, :threshold),
                  finish_weekday: monitoring_events.context_value(context, :finish_weekday),
                  finish_minutes: monitoring_events.context_value(context, :finish_minutes)
                )
              }

  alert_event 'monitoring.vps_in_rescue',
              label: 'VPS in rescue mode',
              template: :alert_vps_in_rescue,
              monitors: %i[vps_in_rescue_mode],
              fields: %i[vps],
              vars: lambda { |base, event, _context|
                base.merge(vps: event.object)
              }

  alert_event 'monitoring.dns_secondary_transfer_failed',
              label: 'DNS secondary transfer failed',
              template: monitoring_state_template.call('dns_secondary_transfer_failure'),
              monitors: %i[dns_secondary_transfer_failure],
              fields: %i[dns]

  alert_event 'monitoring.dataset_over_quota',
              label: 'VPS dataset over quota',
              template: :alert_vps_dataset_over_quota,
              monitors: %i[vps_dataset_expansions],
              fields: %i[vps dataset],
              vars: lambda { |base, event, _context|
                expansion = event.object.dataset_expansion
                base.merge(
                  dataset: event.object,
                  expansion:,
                  vps: expansion.vps
                )
              }

  # Action definitions
  action :route_alert do |event|
    route_monitoring_alert!(event)
  end

  action :route_diskspace_alert do |event|
    dip = event.object.primary_dataset_in_pool!
    vps = if dip.pool.role == 'hypervisor'
            Vps.find_by!(
              dataset_in_pool: dip.dataset.root.primary_dataset_in_pool!
            )
          end

    route_monitoring_alert!(
      event,
      context: {
        dip:,
        pool_role: dip.pool.role,
        vps:
      }
    )
  end

  action :route_admin_alert do |event|
    route_monitoring_alert!(
      event,
      affected_user: event.user,
      context: {
        language: Language.take!
      }
    )
  end

  action :route_zombie_process_alert do |event|
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

      lock(vps)

      route_monitoring_alert!(
        event,
        event_type: 'monitoring.zombie_processes_restart',
        alert_kind: 'restart',
        severity: :critical,
        context: {
          vps:,
          threshold:,
          finish_weekday:,
          finish_minutes:
        }
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
        context: {
          vps:,
          threshold:
        }
      )

      event.action_state ||= {}
      event.action_state['last_alert'] = Time.now.to_i
      event.save!
    end
  end

  action :route_vps_rescue_alert do |event|
    next if event.state == 'closed'

    route_monitoring_alert!(event)
  end

  action :alert_vps_dataset_over_quota do |event|
    next if event.state == 'closed'

    route_monitoring_alert!(event)
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
    action :route_admin_alert
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
    action :route_admin_alert
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
    action :route_diskspace_alert
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
    action :route_alert
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
    action :route_admin_alert
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

    action :route_zombie_process_alert
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

    action :route_alert
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

    action :route_vps_rescue_alert
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

    action :route_alert
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
