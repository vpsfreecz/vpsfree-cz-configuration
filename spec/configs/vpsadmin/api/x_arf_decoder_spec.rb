# frozen_string_literal: true

RSpec.describe AbuseNoticeParser::XArfDecoder do
  subject(:decoder) { described_class.new }

  def encoded_evidence(text = 'synthetic evidence')
    [text].pack('m0')
  end

  def v1_report
    {
      'Version' => '1',
      'ReporterInfo' => {
        'ReporterOrg' => 'Netcraft',
        'ReporterOrgDomain' => 'netcraft.com',
        'ReporterOrgEmail' => 'takedown-response+12345678@netcraft.com'
      },
      'Disclosure' => true,
      'Report' => {
        'ReporterCaseID' => '12345678',
        'Date' => '2026-09-08T15:42:14Z',
        'ReportClass' => 'Activity',
        'ReportType' => 'Spam',
        'ReportSubType' => 'Extortion Mail Server',
        'ReporterNotes' => 'See the synthetic report for more information',
        'SourceIp' => '10.42.9.43',
        'Samples' => [
          {
            'ContentType' => 'message/rfc822',
            'Payload' => encoded_evidence,
            'Base64Encoded' => true
          }
        ]
      }
    }
  end

  def v3_report
    {
      'Version' => '3',
      'ReporterInfo' => {
        'ReporterType' => 'Org',
        'ReporterOrg' => 'Abusix',
        'ReporterOrgDomain' => 'abusix.com',
        'ReporterOrgEmail' => 'reporting-support@abusix.com'
      },
      'Disclosure' => false,
      'Report' => {
        'Date' => '2026-08-17T20:59:40Z',
        'ReportClass' => 'Activity',
        'ReportType' => 'Spam',
        'ReportSubType' => 'Trap',
        'SourceIp' => '10.42.9.42',
        'SmtpMailFromAddress' => 'synthetic-sender@example.test',
        'Sample' => {
          'ContentType' => 'message/rfc822',
          'Payload' => encoded_evidence,
          'Base64Encoded' => true,
          'Description' => 'Redacted headers'
        }
      }
    }
  end

  def v1_content_report
    data = v1_report
    report = data.fetch('Report')
    report.delete('ReportSubType')
    report.delete('Samples')
    report['ReportClass'] = 'Content'
    report['ReportType'] = 'Phishing'
    report['SourceUrl'] = 'https://login.example.test/account/verify'
    report['FirstSeen'] = '2026-09-10T12:00:00Z'
    data
  end

  def v4_report
    {
      'xarf_version' => '4.0.0',
      'report_id' => '123e4567-e89b-42d3-a456-426614174000',
      'timestamp' => '2026-08-19T13:03:45Z',
      'category' => 'messaging',
      'type' => 'spam',
      'reporter' => {
        'org' => 'Example Spam Trap',
        'contact' => 'reports@example.invalid',
        'domain' => 'example.invalid'
      },
      'sender' => {
        'org' => 'Abusix',
        'contact' => 'reporting-support@abusix.com',
        'domain' => 'abusix.com'
      },
      'source_identifier' => '2001:db8::42',
      'source_port' => 46_253,
      'protocol' => 'smtp',
      'evidence_source' => 'spamtrap',
      'smtp_from' => 'v4-sender@example.test',
      'evidence' => [
        {
          'content_type' => 'message/rfc822',
          'description' => 'Redacted headers',
          'payload' => encoded_evidence
        }
      ]
    }
  end

  def decode(data)
    decoder.decode(JSON.generate(data))
  end

  it 'normalizes a Netcraft XARF v1 report' do
    report = decode(v1_report)

    expect(report.version).to eq('1')
    expect(report.source_ip).to eq('10.42.9.43')
    expect(report.detected_at).to eq(Time.utc(2026, 9, 8, 15, 42, 14))
    expect(report.report_class).to eq('Activity')
    expect(report.report_type).to eq('Spam')
    expect(report.report_subtype).to eq('Extortion Mail Server')
    expect(report.report_id).to eq('12345678')
    expect(report.sender_domain).to eq('netcraft.com')
    expect(report.reporter_email).to eq('takedown-response+12345678@netcraft.com')
    expect(report.report_notes).to eq('See the synthetic report for more information')
    expect(report.source_url).to be_nil
    expect(report.disclosure).to be(true)
    expect(report.evidence.first.payload).to eq('synthetic evidence')
  end

  it 'normalizes a Netcraft XARF v1 content report without evidence' do
    report = decode(v1_content_report)

    expect(report.detected_at).to eq(Time.utc(2026, 9, 8, 15, 42, 14))
    expect(report.report_class).to eq('Content')
    expect(report.report_type).to eq('Phishing')
    expect(report.source_url).to eq(
      'https://login.example.test/account/verify'
    )
    expect(report.evidence).to be_empty
  end

  it 'rejects a malformed Samples value instead of treating it as absent' do
    data = v1_content_report
    data.fetch('Report')['Samples'] = false

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'Report.Samples is not an array'
    )
  end

  it 'rejects invalid Unicode in a decoded string' do
    json = JSON.generate(v1_content_report).sub('Phishing', '\\udfff')

    expect { decoder.decode(json) }.to raise_error(
      described_class::Error,
      'ReportType is not a valid string'
    )
  end

  it 'tags decoder errors with an identified XARF version' do
    malformed_reports = [
      [v1_report, '1', 'SourceIp'],
      [v3_report, '3', 'SourceIp'],
      [v4_report, '4.0.0', 'source_identifier']
    ]

    malformed_reports.each do |data, version, source_key|
      report = data.fetch('Report', data)
      report[source_key] = ''

      expect { decode(data) }.to raise_error(described_class::Error) do |error|
        expect(error.version).to eq(version)
      end
    end
  end

  it 'leaves the version unset when it cannot be identified' do
    ambiguous = v1_report.merge('xarf_version' => '4.0.0')
    malformed_version = v1_report.merge('Version' => 1)

    ['{', JSON.generate(ambiguous), JSON.generate(malformed_version)].each do |json|
      expect { decoder.decode(json) }.to raise_error(described_class::Error) do |error|
        expect(error.version).to be_nil
      end
    end
  end

  it 'normalizes an Abusix XARF v3 report with a singular Sample' do
    report = decode(v3_report)

    expect(report.version).to eq('3')
    expect(report.source_ip).to eq('10.42.9.42')
    expect(report.detected_at).to eq(Time.utc(2026, 8, 17, 20, 59, 40))
    expect(report.report_class).to eq('Activity')
    expect(report.report_type).to eq('Spam')
    expect(report.report_subtype).to eq('Trap')
    expect(report.sender_domain).to eq('abusix.com')
    expect(report.disclosure).to be(false)
    expect(report.evidence.first.payload).to eq('synthetic evidence')
  end

  it 'normalizes a standard XARF v3 Samples array' do
    data = v3_report
    sample = data.fetch('Report').delete('Sample')
    data.fetch('Report')['Samples'] = [sample]

    report = decode(data)

    expect(report.evidence.size).to eq(1)
    expect(report.evidence.first.content_type).to eq('message/rfc822')
  end

  it 'preserves ignored reporter metadata in XARF v3 reports' do
    data = v3_report
    data.fetch('ReporterInfo').delete('ReporterOrgEmail')
    data.fetch('Report')['ReporterCaseID'] = 'legacy-case-id'
    data.fetch('Report')['ReporterNotes'] = 'Legacy reporter notes'

    report = decode(data)

    expect(report.reporter_email).to be_nil
    expect(report.report_id).to be_nil
    expect(report.report_notes).to be_nil
    expect(report.source_url).to be_nil
  end

  it 'normalizes an IP-based XARF v4 report' do
    report = decode(v4_report)

    expect(report.version).to eq('4.0.0')
    expect(report.source_ip).to eq('2001:db8::42')
    expect(report.detected_at).to eq(Time.utc(2026, 8, 19, 13, 3, 45))
    expect(report.report_id).to eq('123e4567-e89b-42d3-a456-426614174000')
    expect(report.report_class).to eq('messaging')
    expect(report.report_type).to eq('spam')
    expect(report.protocol).to eq('smtp')
    expect(report.source_port).to eq(46_253)
    expect(report.evidence_source).to eq('spamtrap')
    expect(report.sender_domain).to eq('abusix.com')
    expect(report.source_url).to be_nil
  end

  it 'rejects ambiguous v3 evidence fields' do
    data = v3_report
    data.fetch('Report')['Samples'] = [data.dig('Report', 'Sample')]

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'Report contains both Sample and Samples'
    )
  end

  it 'rejects singular evidence in XARF v1 reports' do
    data = v1_report
    data.fetch('Report')['Sample'] = data.fetch('Report').delete('Samples').first

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'Report.Sample is not supported in XARF version 1'
    )
  end

  it 'rejects a Netcraft v1 report without the reporter email' do
    data = v1_report
    data.fetch('ReporterInfo').delete('ReporterOrgEmail')

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'ReporterOrgEmail is not a valid string'
    )
  end

  it 'rejects an unsupported XARF version' do
    data = v3_report
    data['Version'] = '2'

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'unsupported XARF version "2"'
    )
  end

  it 'rejects a report without a source address' do
    data = v3_report
    data.fetch('Report').delete('SourceIp')

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'SourceIp is not a valid string'
    )
  end

  it 'rejects malformed Base64 evidence' do
    data = v3_report
    data.dig('Report', 'Sample')['Payload'] = '!not-base64!'

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'evidence payload is not valid Base64'
    )
  end

  it 'rejects non-IP v4 source identifiers' do
    data = v4_report
    data['source_identifier'] = 'host.example.test'

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'source identifier is not an IP address'
    )
  end

  it 'rejects invalid event timestamps' do
    data = v3_report
    data.fetch('Report')['Date'] = 'yesterday'

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'event timestamp is not a date-time'
    )
  end

  it 'rejects a timezone-less event timestamp in a non-UTC process timezone' do
    data = v3_report
    data.fetch('Report')['Date'] = '2026-08-19T13:03:45'
    original_timezone = ENV.fetch('TZ', nil)
    ENV['TZ'] = 'Europe/Amsterdam'

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'event timestamp does not include a UTC offset'
    )
  ensure
    ENV['TZ'] = original_timezone
  end

  it 'rejects an invalid source port' do
    data = v4_report
    data['source_port'] = 65_536

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'source_port is not a valid port'
    )
  end

  it 'rejects evidence larger than the configured limit' do
    data = v3_report
    data.dig('Report', 'Sample')['Payload'] = encoded_evidence(
      'x' * (described_class::MAX_EVIDENCE_BYTES + 1)
    )

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'decoded evidence is too large'
    )
  end

  it 'rejects an invalid v4 report ID' do
    data = v4_report
    data['report_id'] = 'not-a-uuid'

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'report_id is not a UUID v4'
    )
  end
end
