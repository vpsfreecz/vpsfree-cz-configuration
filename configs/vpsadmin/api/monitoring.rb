MailTemplate.register :alert_role_event_state,
    name: "alert_%{role}_%{event}_%{state}", params: {
        role: 'user or admin',
        event: 'name of event monitor',
        state: 'event state',
    }, vars: {
        event: 'MonitoredEvent',
        object: 'object associated with this event',
        user: ::User,
        base_url: 'URL to the web UI',
    }

MailTemplate.register :alert_role_diskspace_state_pool,
    name: "alert_%{role}_diskspace_%{state}_%{pool}", params: {
        role: 'user or admin',
        state: 'event state',
        pool: 'primary or hypervisor',
    }, vars: {
        event: 'MonitoredEvent',
        dip: ::DatasetInPool,
        ds: ::Dataset,
        vps: '::Vps or nil',
        user: ::User,
        base_url: 'URL to the web UI',
    }

VpsAdmin::API::Plugins::Monitoring.config do
  # Action definitions
  action :alert_user do |event|
    opts = {
        params: {
            role: :user,
            event: event.monitor.name,
            state: event.state == 'acknowledged' ? 'confirmed' : event.state,
        },
        user: event.user,
        vars: {
            event: event,
            object: event.object,
            user: event.user,
            base_url: ::SysConfig.get('webui', 'base_url'),
        }
    }

    if event.state == 'closed'
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.state}@vpsadmin.vpsfree.cz>"
      rpl_to = "<vpsadmin-monitoring-alert-#{event.id}-confirmed@vpsadmin.vpsfree.cz>"
      opts[:in_reply_to] = rpl_to
      opts[:references] = rpl_to

    else
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-confirmed@vpsadmin.vpsfree.cz>"
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
            pool: dip.pool.role,
        },
        user: event.user,
        vars: {
            event: event,
            dip: dip,
            ds: event.object,
            vps: dip.pool.role == 'hypervisor' ? ::Vps.find_by!(
              dataset_in_pool: dip.dataset.root.primary_dataset_in_pool!,
            ) : nil,
            user: event.user,
            base_url: ::SysConfig.get('webui', 'base_url'),
        }
    }

    if event.state == 'closed'
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.state}@vpsadmin.vpsfree.cz>"
      rpl_to = "<vpsadmin-monitoring-alert-#{event.id}-confirmed@vpsadmin.vpsfree.cz>"
      opts[:in_reply_to] = rpl_to
      opts[:references] = rpl_to

    else
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-confirmed@vpsadmin.vpsfree.cz>"
    end

    opts[:message_id] = msg_id

    mail(:alert_role_diskspace_state_pool, opts)
  end

  action :alert_admins do |event|
    opts = {
        params: {
            role: :admin,
            event: event.monitor.name,
            state: event.state == 'acknowledged' ? 'confirmed' : event.state,
        },
        language: ::Language.take!,
        vars: {
            event: event,
            base_url: ::SysConfig.get('webui', 'base_url'),
        }
    }

    if event.state == 'closed'
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-#{event.state}@vpsadmin.vpsfree.cz>"
      rpl_to = "<vpsadmin-monitoring-alert-#{event.id}-confirmed@vpsadmin.vpsfree.cz>"
      opts[:in_reply_to] = rpl_to
      opts[:references] = rpl_to

    else
      msg_id = "<vpsadmin-monitoring-alert-#{event.id}-confirmed@vpsadmin.vpsfree.cz>"
    end

    opts[:message_id] = msg_id

    mail(:alert_role_event_state, opts)
  end

  # Monitors
  ## Unpaid users
  monitor :unpaid_cpu do
    label 'VPS CPU time of unpaid users'
    desc 'The VPS used more than 200% CPU for the last 30 or more minutes'
    period 30*60
    repeat 10*60
    access_level 90

    query do
      ::Vps.joins(
          :vps_current_status, user: :user_account
      ).includes(
          :vps_current_status
      ).where(
          users: {object_state: ::User.object_states[:active]},
          user_accounts: {paid_until: nil},
          vpses: {object_state: ::Vps.object_states[:active]},
          vps_current_statuses: {status: true, is_running: true},
      )
    end

    value do |vps|
      (vps.vps_current_status.cpus * 100) - (vps.vps_current_status.cpu_idle * vps.vps_current_status.cpus)
    end
    check { |vps, v| v.nil? || v < 200 }
    action :alert_admins
  end

  monitor :unpaid_data_flow do
    label 'Public IP traffic of unpaid users'
    desc 'Data transfer rate was faster than 200 Mbps for the last 30 or more minutes'
    period 30*60
    repeat 10*60
    access_level 90

    query do
      ::IpTrafficLiveMonitor.select(
          "#{::IpTrafficLiveMonitor.table_name}.*, SUM(public_bytes_out) AS bytes_all"
      ).joins(
          ip_address: {vps: [:vps_current_status, user: :user_account]}
      ).where(
          users: {object_state: ::User.object_states[:active]},
          user_accounts: {paid_until: nil},
          vpses: {object_state: ::Vps.object_states[:active]},
          vps_current_statuses: {status: true, is_running: true},
      ).group('vpses.id')
    end

    object { |mon| mon.ip_address.vps }
    value { |mon| mon.bytes_all }
    check { |mon, v| (v * 8) < 200*1024*1024 }
    action :alert_admins
  end

  ## Others
  monitor :diskspace do
    label 'Dataset free space'
    desc 'The dataset has less than 10 % of free space'
    check_count 1
    repeat 1*24*60*60
    cooldown 6*60*60

    query do
      ::DatasetInPool.joins(
          :pool, dataset: [:user]
      ).includes(
          :pool, :dataset_properties, dataset: :user
      ).where(
          users: {object_state: ::User.object_states[:active]},
          pools: {role: [
              ::Pool.roles[:primary],
              ::Pool.roles[:hypervisor],
          ]},
      )
    end

    object { |dip| dip.dataset }
    value do |dip|
      if dip.used > 0
        dip.avail.to_f / (dip.pool.refquota_check ? dip.refquota : dip.dataset.effective_quota) * 100

      else
        100
      end
    end

    check { |dip, v| v > 10 }
    user { |dip| dip.dataset.user }
    action :alert_user_diskspace
  end
  
  monitor :paid_cpu do
    label 'VPS CPU time'
    desc 'The VPS used more than 300% CPU for the last 3 or more days'
    period 3*24*60*60
    repeat 1*24*60*60

    query do
      ::Vps.joins(:vps_current_status, user: :user_account).where(
          users: {object_state: ::User.object_states[:active]},
          vpses: {object_state: ::Vps.object_states[:active]},
          vps_current_statuses: {status: true, is_running: true},
      ).includes(
          :vps_current_status
      ).where.not(
          user_accounts: {paid_until: nil},
      )
    end

    value do |vps|
      (vps.vps_current_status.cpus * 100) - (vps.vps_current_status.cpu_idle * vps.vps_current_status.cpus)
    end
    check { |vps, v| v.nil? || v < 300 }
    action :alert_user
  end

  monitor :monthly_traffic do
    label 'Monthly traffic'
    desc "The user's monthly traffic is now more than 10 TiB"
    check_count 1
    repeat 7*24*60*60
    access_level 90

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
    action :alert_admins
  end
end
