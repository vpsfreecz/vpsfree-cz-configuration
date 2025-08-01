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
    opts = {
      params: {
        role: :user,
        event: event.monitor.name,
        state: event.state == 'acknowledged' ? 'confirmed' : event.state
      },
      user: event.user,
      vars: {
        event: event,
        object: event.object,
        user: event.user,
        base_url: SysConfig.get('webui', 'base_url')
      }
    }

    if event.state == 'closed'
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-#{event.state}@vpsadmin.vpsfree.cz>"
      rpl_to = "<vpsadmin-monitoring-alert-#{event.id}-#{event.prev_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
      opts[:in_reply_to] = rpl_to
      opts[:references] = rpl_to

    else
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
    end

    opts[:message_id] = msg_id

    mail(:alert_role_event_state, opts)
  end

  action :alert_user_diskspace do |event|
    dip = event.object.primary_dataset_in_pool!
    opts = {
      params: {
        role: :user,
        state: event.state == 'acknowledged' ? 'confirmed' : event.state,
        pool: dip.pool.role
      },
      user: event.user,
      vars: {
        event: event,
        dip: dip,
        ds: event.object,
        vps: if dip.pool.role == 'hypervisor'
               Vps.find_by!(
                 dataset_in_pool: dip.dataset.root.primary_dataset_in_pool!
               )
             end,
        user: event.user,
        base_url: SysConfig.get('webui', 'base_url')
      }
    }

    if event.state == 'closed'
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-#{event.state}@vpsadmin.vpsfree.cz>"
      rpl_to = "<vpsadmin-monitoring-alert-#{event.id}-#{event.prev_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
      opts[:in_reply_to] = rpl_to
      opts[:references] = rpl_to

    else
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
    end

    opts[:message_id] = msg_id

    mail(:alert_role_diskspace_state_pool, opts)
  end

  action :alert_admins do |event|
    opts = {
      params: {
        role: :admin,
        event: event.monitor.name,
        state: event.state == 'acknowledged' ? 'confirmed' : event.state
      },
      language: Language.take!,
      vars: {
        event: event,
        base_url: SysConfig.get('webui', 'base_url')
      }
    }

    if event.state == 'closed'
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-#{event.state}@vpsadmin.vpsfree.cz>"
      rpl_to = "<vpsadmin-monitoring-alert-#{event.id}-#{event.prev_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
      opts[:in_reply_to] = rpl_to
      opts[:references] = rpl_to

    else
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
    end

    opts[:message_id] = msg_id

    mail(:alert_role_event_state, opts)
  end

  action :alert_user_zombie_processes do |event|
    threshold = 10_000
    vps = event.object

    mail_vars = {
      event: event,
      vps: vps,
      zombie_process_count: vps.zombie_process_count,
      threshold: threshold,
      user: event.user,
      base_url: SysConfig.get('webui', 'base_url')
    }

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
        user: event.user,
        vars: mail_vars.merge({
          finish_weekday: finish_weekday,
          finish_minutes: finish_minutes
        })
      }

      lock(vps)

      mail(:alert_user_zombie_processes_restart, opts)

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

      opts = {
        params: {
          state: event.state == 'acknowledged' ? 'confirmed' : event.state
        },
        user: event.user,
        vars: mail_vars
      }

      if event.state == 'closed'
        msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-#{event.state}@vpsadmin.vpsfree.cz>"
        rpl_to = "<vpsadmin-monitoring-alert-#{event.id}-#{event.prev_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
        opts[:in_reply_to] = rpl_to
        opts[:references] = rpl_to
      else
        msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.next_alert_id}-confirmed@vpsadmin.vpsfree.cz>"
      end

      opts[:message_id] = msg_id

      mail(:alert_user_zombie_processes_state, opts)

      event.action_state ||= {}
      event.action_state['last_alert'] = Time.now.to_i
      event.save!
    end
  end

  action :alert_user_vps_in_rescue do |event|
    next if event.state == 'closed'

    opts = {
      user: event.user,
      vars: {
        event: event,
        vps: event.object,
        user: event.user,
        base_url: SysConfig.get('webui', 'base_url')
      }
    }

    mail(:alert_user_vps_in_rescue, opts)
  end

  action :alert_vps_dataset_over_quota do |event|
    next if event.state == 'closed'

    opts = {
      user: event.user,
      vars: {
        event: event,
        dataset: event.object,
        expansion: event.object.dataset_expansion,
        vps: event.object.dataset_expansion.vps,
        user: event.user,
        base_url: SysConfig.get('webui', 'base_url')
      }
    }

    mail(:alert_vps_dataset_over_quota, opts)
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

    object { |dip| dip.dataset }
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

    object { |tr| tr.user }
    value { |tr| tr.bytes_all }
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

    user do |vps|
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

    user do |ds|
      ds.user
    end

    value do |ds|
      ds.refquota
    end

    check do |ds, _value|
      ds.referenced < ds.dataset_expansion.original_refquota
    end

    action :alert_vps_dataset_over_quota
  end
end
