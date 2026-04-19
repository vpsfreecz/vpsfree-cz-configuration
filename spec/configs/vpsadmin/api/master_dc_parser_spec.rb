# frozen_string_literal: true

RSpec.describe AbuseNoticeParser::MasterDc do
  it 'parses a MasterDC SPFBL abuse report' do
    incidents = parse_fixture(described_class, 'masterdc_spfbl', assignments: ['172.16.15.43'])

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq('[rt.i.masterinter.net #755614] Abuse report #1irmmcone from 172.16.15.43')
    expect(incident.detected_at).to eq(Time.new(2025, 5, 20, 8, 13, 52, '-03:00'))
    expect(incident.text).to include('IP adresa 172.16.15.43')
    expect(incident.text).to include('Source-IP: 172.16.15.43')
  end

  it 'parses a MasterDC Spamhaus SBL notification' do
    incidents = parse_fixture(described_class, 'masterdc_sbl', assignments: ['172.20.13.125'])

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq('[rt.i.masterinter.net #787048] SBL Notify: IP: 172.20.13.125 added to Spamhaus Block List (SBL)')
    expect(incident.detected_at).to eq(Time.new(2025, 11, 17, 7, 25, 52, '+01:00'))
    expect(incident.text).to include('SBL689267')
    expect(incident.text).to include('Problem: Phishing server')
  end

  it 'parses a MasterDC UCEPROTECT monitoring report' do
    incidents = parse_fixture(described_class, 'masterdc_uceprotect', assignments: ['192.168.65.60'])

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq('[MasterDC support #702321] UCEPROTECT Monitoring Report (192.168.65.60)')
    expect(incident.detected_at).to eq(Time.at(1_726_798_443))
    expect(incident.text).to include('192.168.65.60,1726798443')
  end
end
