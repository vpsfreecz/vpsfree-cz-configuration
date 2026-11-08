# frozen_string_literal: true

require_relative '../../../../configs/vpsadmin/api/dns_transfer_monitor'

module DnsTransferMonitorSpec
  class Relation
    def existing; end
    def primary_type; end
    def secondary_type; end
    def joins(*); end
    def where(*); end
    def pluck(*); end
    def exists?; end
    def failed; end
    def order(*); end
    def last; end
  end

  class Zone
    attr_reader :id, :dns_server_zones, :dns_zone_transfers,
                :dns_server_zone_primary_transfer_states,
                :alert_eligible_primary_transfer_state_count, :failed_primary_transfer_state_count

    def enabled?; end
    def external_source?; end
    def primary_transfer_failure_resolution; end
    def primary_transfer_failure_monitor_passed?(incident_active:); end
  end

  Event = Struct.new(:state, :object, :monitored_event_logs, :action_state, keyword_init: true) do
    def update!(**); end
  end

  class Events
    def self.find_by(**); end
  end
end

RSpec.describe VpsAdmin::Configuration::DnsTransferMonitor do
  let(:zone) do
    instance_double(DnsTransferMonitorSpec::Zone, id: 7, enabled?: true, external_source?: true,
                                                  dns_server_zones: servers, dns_zone_transfers: primaries,
                                                  dns_server_zone_primary_transfer_states: states,
                                                  alert_eligible_primary_transfer_state_count: 0,
                                                  failed_primary_transfer_state_count: 0,
                                                  primary_transfer_failure_resolution: nil)
  end
  let(:servers) { instance_double(DnsTransferMonitorSpec::Relation) }
  let(:primaries) { instance_double(DnsTransferMonitorSpec::Relation) }
  let(:states) { instance_double(DnsTransferMonitorSpec::Relation) }
  let(:event) do
    logs = instance_double(DnsTransferMonitorSpec::Relation)
    value = { 'failed_paths' => [[11, 21]] }
    allow(logs).to receive(:order).with(:id).and_return(logs)
    allow(logs).to receive(:last).and_return(Struct.new(:value).new(value))
    DnsTransferMonitorSpec::Event.new(monitored_event_logs: logs, state: 'confirmed', object: zone)
  end

  def previous_value
    event.monitored_event_logs.order(:id).last.value
  end

  before do
    allow(servers).to receive_messages(existing: servers, secondary_type: servers, joins: servers, where: servers)
    allow(servers).to receive(:pluck).with(:id).and_return([11, 12])
    allow(primaries).to receive_messages(existing: primaries, primary_type: primaries, exists?: true)
    allow(primaries).to receive(:pluck).with(:id).and_return([21])
    allow(states).to receive(:failed).and_return(states)
    allow(states).to receive(:pluck).with(:dns_server_zone_id, :dns_zone_transfer_id).and_return([])
    stub_const('MonitoredEvent', DnsTransferMonitorSpec::Events)
    allow(MonitoredEvent).to receive(:find_by).and_return(event)
    allow(zone).to receive(:primary_transfer_failure_monitor_passed?).with(incident_active: true).and_return(false)
  end

  it 'uses the complete visible-secondary and existing-user-primary configuration matrix' do
    expect(described_class.expected_paths(zone)).to eq([[11, 21], [12, 21]])
    expect(servers).to have_received(:existing)
    expect(servers).to have_received(:secondary_type)
    expect(servers).to have_received(:where).with(dns_servers: { hidden: false })
    expect(primaries).to have_received(:existing)
    expect(primaries).to have_received(:primary_type)
  end

  it 'keeps stale or absent observations open while the same endpoints exist' do
    value = described_class.value(zone)

    expect(value['resolution']).to be_nil
    expect(described_class.passed?(zone, value)).to be(false)
  end

  it 'does not treat generation-only churn of an endpoint as configuration removal' do
    allow(zone).to receive(:primary_transfer_failure_monitor_passed?).and_return(false)

    expect(described_class.value(zone)['resolution']).to be_nil
  end

  it 'retains an incident after partial removal if one remembered stale failure still exists' do
    previous_value['failed_paths'] = [[11, 20], [11, 21]]

    expect(described_class.value(zone)['resolution']).to be_nil
  end

  it 'closes for explicit removal when all remembered failed paths were replaced by pending paths' do
    allow(primaries).to receive(:pluck).with(:id).and_return([22])
    value = described_class.value(zone)

    expect(value['resolution']).to eq('configuration_changed')
    expect(described_class.passed?(zone, value)).to be(true)
  end

  it 'does not close vacuously when no failed path was remembered' do
    previous_value['failed_paths'] = []

    expect(described_class.value(zone)['resolution']).to be_nil
  end

  it 'does not turn a failed configuration read into removal evidence' do
    allow(primaries).to receive(:pluck).with(:id).and_raise(IOError, 'configuration unavailable')

    expect { described_class.value(zone) }.to raise_error(IOError, 'configuration unavailable')
  end

  it 'does not close when a remaining path has a known failure even if stale or not alert-eligible' do
    previous_value['failed_paths'] = [[11, 20]]
    allow(states).to receive(:pluck).with(:dns_server_zone_id, :dns_zone_transfer_id).and_return([[12, 21]])

    expect(described_class.value(zone)['resolution']).to be_nil
    expect(described_class.value(zone)['failed_paths']).to eq([[11, 20], [12, 21]])
  end

  it 'delegates positive recovery to the shared model predicate' do
    allow(zone).to receive_messages(
      primary_transfer_failure_resolution: 'recovered',
      primary_transfer_failure_monitor_passed?: true
    )
    value = described_class.value(zone)

    expect(value['resolution']).to eq('recovered')
    expect(described_class.passed?(zone, value)).to be(true)
  end

  it 'does not call removed failed paths recovered when every retained path is positive' do
    previous_value['failed_paths'] = [[11, 20], [11, 21]]
    allow(zone).to receive(:primary_transfer_failure_resolution).and_return('recovered')

    expect(described_class.value(zone)['resolution']).to eq('configuration_changed')
  end

  it 'opens a new incident only through the shared currentness-aware eligibility predicate' do
    allow(MonitoredEvent).to receive(:find_by).and_return(nil)
    allow(zone).to receive(:primary_transfer_failure_monitor_passed?).with(incident_active: false).and_return(true)

    expect(described_class.passed?(zone, described_class.value(zone))).to be(true)
  end

  it 'does not report missing configuration for an owned detached primary reference' do
    expect(described_class.missing_value(zone)['missing']).to be(false)
    expect(primaries).to have_received(:existing)
    expect(primaries).to have_received(:primary_type)
  end

  it 'reports missing user primaries even when healthy peer secondaries exist' do
    allow(primaries).to receive(:exists?).and_return(false)

    expect(described_class.missing_value(zone)).to eq('missing' => true, 'resolution' => nil)
  end

  it 'resolves last-primary removal as configuration changed and re-addition as restored, not ready' do
    allow(primaries).to receive(:pluck).with(:id).and_return([])
    allow(primaries).to receive(:exists?).and_return(false)
    allow(zone).to receive(:primary_transfer_failure_resolution).and_return('configuration_changed')

    expect(described_class.value(zone)['resolution']).to eq('configuration_changed')
    expect(described_class.missing_value(zone)['missing']).to be(true)

    allow(primaries).to receive(:exists?).and_return(true)
    expect(described_class.missing_value(zone)['resolution']).to eq('configuration_restored')
  end

  it 'uses the association confirmation boundary again after a removal rollback' do
    allow(primaries).to receive(:pluck).with(:id).and_return([21])
    allow(primaries).to receive(:exists?).and_return(true)

    expect(described_class.value(zone)['resolution']).to be_nil
    expect(described_class.missing_value(zone)['missing']).to be(false)
  end

  it 'does not open missing configuration for disabled or internal zones' do
    allow(primaries).to receive(:exists?).and_return(false)
    allow(zone).to receive(:enabled?).and_return(false)
    expect(described_class.missing_value(zone)).to eq('missing' => false, 'resolution' => 'configuration_changed')

    allow(zone).to receive_messages(enabled?: true, external_source?: false)
    expect(described_class.missing_value(zone)['missing']).to be(false)
  end

  it 'suppresses repeats with no fresh eligible failure and respects acknowledged or ignored events' do
    expect(described_class.send_alert?(event)).to be(false)
    allow(zone).to receive(:alert_eligible_primary_transfer_state_count).and_return(1)
    expect(described_class.send_alert?(event)).to be(true)

    %w[acknowledged ignored].each do |state|
      allow(event).to receive(:state).and_return(state)
      expect(described_class.send_alert?(event)).to be(false)
    end
  end

  it 'snapshots the measured close reason while preserving unrelated action state' do
    previous_value['resolution'] = 'configuration_changed'
    allow(event).to receive_messages(state: 'closed', action_state: { 'previous' => 1 })
    allow(event).to receive(:update!)

    described_class.snapshot_resolution!(event)

    expect(event).to have_received(:update!).with(
      action_state: { 'previous' => 1, 'dns_primary_transfer_closure_reason' => 'configuration_changed' }
    )
    expect(described_class.send_alert?(event)).to be(true)
  end
end
