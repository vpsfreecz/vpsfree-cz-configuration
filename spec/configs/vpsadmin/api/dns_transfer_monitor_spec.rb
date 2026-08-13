# frozen_string_literal: true

require_relative '../../../../configs/vpsadmin/api/dns_transfer_monitor'

RSpec.describe VpsAdmin::Configuration::DnsTransferMonitor do
  let(:zone_class) do
    Class.new do
      attr_accessor :alert_eligible_primary_transfer_state_count,
                    :failed_primary_transfer_state_count,
                    :active_event_count

      def initialize(alert_eligible:, failed:, active:)
        self.alert_eligible_primary_transfer_state_count = alert_eligible
        self.failed_primary_transfer_state_count = failed
        self.active_event_count = active
      end

      def [](name)
        return active_event_count if name == :active_dns_transfer_failure_event_count

        raise KeyError, name
      end

      def primary_transfer_failure_monitor_passed?(incident_active:)
        count = incident_active ? failed_primary_transfer_state_count : alert_eligible_primary_transfer_state_count
        count == 0
      end
    end
  end

  let(:event_class) { Struct.new(:state, :object, keyword_init: true) }

  it 'holds an active incident open for a young overlapping failure' do
    zone = zone_class.new(
      alert_eligible: 0,
      failed: 1,
      active: 1
    )
    value = described_class.value(zone)

    expect(described_class.passed?(zone, value)).to be(false)
  end

  it 'suppresses a repeat alert until a remaining path becomes eligible' do
    zone = zone_class.new(
      alert_eligible: 0,
      failed: 1,
      active: 1
    )
    event = event_class.new(state: 'confirmed', object: zone)

    expect(described_class.send_alert?(event)).to be(false)

    zone.alert_eligible_primary_transfer_state_count = 1
    expect(described_class.send_alert?(event)).to be(true)
  end

  it 'always sends the final closed notification' do
    zone = zone_class.new(
      alert_eligible: 0,
      failed: 0,
      active: 0
    )
    event = event_class.new(state: 'closed', object: zone)

    expect(described_class.send_alert?(event)).to be(true)
  end
end
