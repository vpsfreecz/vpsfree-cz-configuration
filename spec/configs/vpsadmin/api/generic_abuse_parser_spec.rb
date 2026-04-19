# frozen_string_literal: true

RSpec.describe AbuseNoticeParser do
  describe AbuseNoticeParser::Fail2Ban do
    it 'parses access-log abuse notices and uses the newest log timestamp' do
      incidents = parse_fixture(described_class, 'access_log_abuse', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.subject).to eq('Abuse from 10.42.9.42')
      expect(incident.detected_at).to eq(Time.new(2026, 4, 19, 7, 18, 38, '+02:00'))
      expect(incident.text).to include('We have detected abuse')
      expect(incident.text).to include('19/Apr/2026:07:18:38 +0200')
    end
  end

  describe AbuseNoticeParser::XArf do
    it 'parses X-ARF style multipart reports' do
      incidents = parse_fixture(described_class, 'x_arf_login_attack', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.subject).to eq('abuse report about 10.42.9.42 - 2026-04-17T17:02:02-0400')
      expect(incident.detected_at).to eq(Time.new(2026, 4, 17, 17, 2, 2, '-04:00'))
      expect(incident.text).to include('Report-Type: login-attack')
      expect(incident.text).to include('example.net:443 10.42.9.42')
    end
  end
end
