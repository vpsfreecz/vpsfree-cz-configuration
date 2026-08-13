# frozen_string_literal: true

module VpsAdmin
  module Configuration
    module DnsTransferMonitor
      module_function

      def value(zone)
        {
          alert_eligible: zone.alert_eligible_primary_transfer_state_count,
          failed: zone.failed_primary_transfer_state_count,
          incident_active: zone[:active_dns_transfer_failure_event_count].to_i > 0
        }
      end

      def passed?(zone, value)
        zone.primary_transfer_failure_monitor_passed?(
          incident_active: value[:incident_active]
        )
      end

      def send_alert?(event)
        event.state == 'closed' ||
          event.object.alert_eligible_primary_transfer_state_count > 0
      end
    end
  end
end
