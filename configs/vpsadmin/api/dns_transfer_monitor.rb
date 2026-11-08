# frozen_string_literal: true

module VpsAdmin
  module Configuration
    module DnsTransferMonitor
      READINESS_MONITOR = 'dns_primary_transfer_failure'
      MISSING_MONITOR = 'dns_secondary_missing_primary'
      ACTIVE_STATES = %i[monitoring confirmed acknowledged ignored].freeze

      module_function

      def zones
        DnsZone.existing.joins(:user).where(users: { object_state: User.object_states[:active] })
      end

      def monitored_zone?(zone)
        zone.enabled? && zone.external_source?
      end

      def user_primaries(zone)
        zone.dns_zone_transfers.existing.primary_type
      end

      def expected_paths(zone)
        server_ids = zone.dns_server_zones.existing.secondary_type
                         .joins(:dns_server).where(dns_servers: { hidden: false }).pluck(:id)
        server_ids.product(user_primaries(zone).pluck(:id)).sort
      end

      def active_event(zone, name)
        MonitoredEvent.find_by(monitor_name: name, class_name: 'DnsZone', row_id: zone.id, state: ACTIVE_STATES)
      end

      def measured_value(event)
        return {} unless event

        value = event.monitored_event_logs.order(:id).last&.value
        value.is_a?(Hash) ? value : {}
      end

      def value(zone)
        event = active_event(zone, READINESS_MONITOR)
        expected = expected_paths(zone)
        failed = zone.dns_server_zone_primary_transfer_states.failed
                     .pluck(:dns_server_zone_id, :dns_zone_transfer_id) & expected
        remembered = measured_value(event).fetch('failed_paths', [])
        resolution = zone.primary_transfer_failure_resolution

        if resolution == 'recovered' && (remembered - expected).any?
          resolution = 'configuration_changed'
        end

        # An absent observation is not removal. Compare durable endpoint IDs with
        # the complete configuration matrix, independently of probe freshness.
        if resolution.nil? && remembered.any? && failed.empty? && !remembered.intersect?(expected)
          resolution = 'configuration_changed'
        end

        {
          'alert_eligible' => zone.alert_eligible_primary_transfer_state_count,
          'failed' => zone.failed_primary_transfer_state_count,
          'incident_active' => !event.nil?,
          'failed_paths' => (remembered | failed).sort,
          'resolution' => resolution
        }
      end

      def passed?(zone, value)
        return true unless monitored_zone?(zone)
        return true if value['incident_active'] && value['resolution'] == 'configuration_changed'

        zone.primary_transfer_failure_monitor_passed?(incident_active: value['incident_active'])
      end

      def missing_value(zone)
        configured = user_primaries(zone).exists?
        {
          'missing' => monitored_zone?(zone) && !configured,
          'resolution' => if !monitored_zone?(zone)
                            'configuration_changed'
                          elsif configured
                            'configuration_restored'
                          end
        }
      end

      def send_alert?(event)
        event.state == 'closed' ||
          (event.state == 'confirmed' && event.object.alert_eligible_primary_transfer_state_count > 0)
      end

      def snapshot_resolution!(event, key: 'dns_primary_transfer_closure_reason')
        return unless event.state == 'closed'

        event.update!(
          action_state: (event.action_state || {}).merge(
            key => measured_value(event).fetch('resolution', nil) || 'configuration_changed'
          )
        )
      end
    end
  end
end
