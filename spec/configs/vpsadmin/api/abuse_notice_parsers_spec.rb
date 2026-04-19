# frozen_string_literal: true

RSpec.describe AbuseNoticeParser do
  describe AbuseNoticeParser::BitNinja do
    it 'parses a BitNinja attack-source notice' do
      incidents = parse_fixture(described_class, 'bitninja', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.user_id).to eq(1001)
      expect(incident.vps_id).to eq(2002)
      expect(incident.subject).to eq('Your server 10.42.9.42 has been registered as an attack source')
      expect(incident.detected_at).to eq(Time.utc(2025, 1, 2, 3, 4, 5))
      expect(incident.text).to include('Attack type: http-botnet')
    end
  end

  describe AbuseNoticeParser::Fail2Ban do
    it 'parses the original fail2ban abuse report format' do
      incidents = parse_fixture(described_class, 'fail2ban', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.subject).to eq('Automatic abuse report for IP address 10.42.9.42')
      expect(incident.detected_at).to eq(Time.utc(2023, 9, 15, 18, 55, 37))
      expect(incident.text).to include('Log line for 10.42.9.42 follows')
    end
  end

  describe AbuseNoticeParser::LeakIX do
    it 'parses a LeakIX critical security report' do
      incidents = parse_fixture(described_class, 'leakix', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.subject).to eq('[LeakIX] Critical security issue for 10.42.9.42')
      expect(incident.detected_at).to eq(Time.utc(2025, 1, 2, 3, 4))
      expect(incident.text).to include('| Host       | 10.42.9.42')
    end
  end

  describe AbuseNoticeParser::Proki do
    it 'parses the newest PROKI incident from a zipped CSV attachment' do
      incidents = parse_fixture(described_class, 'proki', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.subject).to eq('PROKI Malware-C2 2025-01-02')
      expect(incident.codename).to eq('Malware-C2')
      expect(incident.detected_at).to eq(Time.utc(2025, 1, 2, 3, 4, 5))
      expect(incident.text).to include('feed_name           : Malware-C2')
      expect(IncidentReport.where_calls.size).to eq(1)
    end
  end

  describe AbuseNoticeParser::SpamCop do
    it 'parses a SpamCop report' do
      incidents = parse_fixture(described_class, 'spamcop', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.subject).to eq('[SpamCop (10.42.9.42) id:123456] spam report')
      expect(incident.detected_at).to eq(Time.utc(2025, 1, 2, 3, 4, 5))
      expect(incident.text).to include('SpamCop evidence body')
    end
  end

  describe AbuseNoticeParser::UsGo do
    it 'parses a USGO ARF multipart report' do
      incidents = parse_fixture(described_class, 'usgo', assignments: ['10.42.9.42'])

      expect(incidents.size).to eq(1)
      incident = incidents.first
      expect(incident.subject).to eq('Abuse Feedback Report for 10.42.9.42')
      expect(incident.detected_at).to eq(Time.utc(2025, 1, 2, 3, 4, 5))
      expect(incident.text).to include('A USGO abuse feedback report was received')
      expect(incident.text).to include('Offending message:')
      expect(incident.text).to include('Offending message headers and body')
    end
  end
end
