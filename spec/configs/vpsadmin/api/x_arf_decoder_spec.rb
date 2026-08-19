# frozen_string_literal: true

RSpec.describe AbuseNoticeParser::XArfDecoder do
  subject(:decoder) { described_class.new }

  def encoded_evidence(text = 'synthetic evidence')
    [text].pack('m0')
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
  end

  it 'rejects ambiguous v3 evidence fields' do
    data = v3_report
    data.fetch('Report')['Samples'] = [data.dig('Report', 'Sample')]

    expect { decode(data) }.to raise_error(
      described_class::Error,
      'Report contains both Sample and Samples'
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
