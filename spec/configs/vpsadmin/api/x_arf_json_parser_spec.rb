# frozen_string_literal: true

RSpec.describe AbuseNoticeParser::XArfJson do
  def fixture_with_json(name)
    message = fixture_message(name)
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    data = JSON.parse(attachment.decoded)
    yield data
    attachment.body = JSON.generate(data)
    attachment.content_transfer_encoding = '8bit'
    message
  end

  def parse_message(message, assignments: [], dry_run: true)
    assignments.each { |ip| register_assignment(ip) }
    described_class.new(mailbox, message, dry_run: dry_run).parse
  end

  it 'creates an incident from an Abusix XARF v3 spam report' do
    incidents = parse_fixture(
      described_class,
      'x_arf_json_v3',
      assignments: ['10.42.9.42']
    )

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq('Spam report for 10.42.9.42')
    expect(incident.detected_at).to eq(Time.utc(2026, 8, 17, 20, 59, 40))
    expect(incident.text).to include('A spam trap received an email from this IP address.')
    expect(incident.text).to include('Envelope sender: synthetic-sender@example.test')
    expect(incident.text).to include('Subject: Synthetic spam sample')
    expect(incident.text).to include('BODY REDACTED')
    expect(incident.text).not_to include('reporting-support@abusix.com')
    expect(incident.text).not_to include('data-channel.example.invalid')
    expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq(
      [{ addr_str: '10.42.9.42', time: Time.utc(2026, 8, 17, 20, 59, 40) }]
    )
  end

  it 'creates an incident from a Netcraft XARF v1 extortion report' do
    incidents = parse_fixture(
      described_class,
      'x_arf_json_v1_netcraft',
      assignments: ['10.42.9.43']
    )

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq(
      'Netcraft issue 12345678: Extortion Mail Server at 10.42.9.43'
    )
    expect(incident.detected_at).to eq(Time.utc(2026, 9, 8, 15, 42, 14))
    expect(incident.text).to include(
      'Netcraft reported this IP address as an email server sending extortion messages.'
    )
    expect(incident.text).to include('Netcraft issue: 12345678')
    expect(incident.text).to include(
      'Details: See https://incident.example.test/reports/synthetic for more information'
    )
    expect(incident.text).to include('Subject: Synthetic extortion sample')
    expect(incident.text).to include('SYNTHETIC EVIDENCE')
    expect(incident.text).not_to include('takedown-response+12345678@netcraft.com')
    expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq(
      [{ addr_str: '10.42.9.43', time: Time.utc(2026, 9, 8, 15, 42, 14) }]
    )
  end

  it 'creates an incident from a Netcraft XARF v1 content report' do
    incidents = parse_fixture(
      described_class,
      'x_arf_json_v1_netcraft_content',
      assignments: ['10.42.9.44']
    )

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq(
      'Netcraft issue 23456789: Phishing at 10.42.9.44'
    )
    expect(incident.detected_at).to eq(Time.utc(2026, 9, 9, 10, 15, 0))
    expect(incident.text).to include(
      'Netcraft reported harmful content hosted at this IP address.'
    )
    expect(incident.text).to include('Netcraft issue: 23456789')
    expect(incident.text).to include('Report type: Phishing')
    expect(incident.text).to include(
      'Reported URL: https://login.example.test/account/verify?case=23456789'
    )
    expect(incident.text).to include(
      'Details: See the reported URL for more information'
    )
    expect(incident.text).not_to include('Reported evidence:')
    expect(incident.text).not_to include(
      'takedown-response+23456789@netcraft.com'
    )
    expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq(
      [{ addr_str: '10.42.9.44', time: Time.utc(2026, 9, 9, 10, 15, 0) }]
    )
  end

  it 'accepts other safe Netcraft content report types' do
    ['Malware', 'New Content Category'].each do |report_type|
      message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
        data.fetch('Report')['ReportType'] = report_type
      end

      incidents = parse_message(message, assignments: ['10.42.9.44'])

      expect(incidents.size).to eq(1)
      expect(incidents.first.subject).to eq(
        "Netcraft issue 23456789: #{report_type} at 10.42.9.44"
      )
    end
  end

  it 'accepts an HTTP Netcraft content source URL' do
    message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
      data.fetch('Report')['SourceUrl'] =
        'http://login.example.test/account/verify'
    end

    incidents = parse_message(message, assignments: ['10.42.9.44'])

    expect(incidents.size).to eq(1)
    expect(incidents.first.text).to include(
      'Reported URL: http://login.example.test/account/verify'
    )
  end

  it 'creates an incident from an IP-based XARF v4 spam report' do
    incidents = parse_fixture(
      described_class,
      'x_arf_json_v4',
      assignments: ['2001:db8::42']
    )

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq('Spam report for 2001:db8::42')
    expect(incident.detected_at).to eq(Time.utc(2026, 8, 19, 13, 3, 45))
    expect(incident.text).to include(
      'Report ID: 123e4567-e89b-42d3-a456-426614174000'
    )
    expect(incident.text).to include('Subject: Synthetic XARF v4 spam sample')
    expect(incident.text).not_to include('reports@example.invalid')
  end

  it 'does not create an incident without a historical IP assignment' do
    incidents = parse_message(fixture_message('x_arf_json_v3'))

    expect(incidents).to be_empty
  end

  it 'does not create a Netcraft incident without a historical IP assignment' do
    incidents = parse_message(fixture_message('x_arf_json_v1_netcraft'))

    expect(incidents).to be_empty
  end

  it 'does not create a Netcraft content incident without an IP assignment' do
    incidents = parse_message(
      fixture_message('x_arf_json_v1_netcraft_content')
    )

    expect(incidents).to be_empty
  end

  it 'does not match reports from untrusted RT originators' do
    message = fixture_message('x_arf_json_v3')

    expect(
      described_class.match_message?(
        'Abuse Report: Spam',
        'attacker@example.test',
        message: message,
        check_sender: true
      )
    ).to be(false)
    expect(
      described_class.match_message?(
        'Abuse Report: Spam',
        'attacker@example.test',
        message: message,
        check_sender: false
      )
    ).to be(true)
  end

  it 'matches Netcraft dynamic RT originators' do
    message = fixture_message('x_arf_json_v1_netcraft')

    expect(
      described_class.match_message?(
        'Issue 12345678: Server involved in fraud at 10.42.9.43',
        'takedown-response+12345678@netcraft.com',
        message: message,
        check_sender: true
      )
    ).to be(true)
  end

  it 'does not match a message with duplicate JSON report attachments' do
    message = fixture_message('x_arf_json_v3')
    duplicate = Mail::Part.new do
      content_type 'application/json; name=xarf.json'
      content_disposition 'attachment; filename=xarf.json'
      body '{}'
    end
    message.add_part(duplicate)

    expect(
      described_class.match_message?(
        'Abuse Report: Spam',
        'support@abusix.com',
        message: message,
        check_sender: true
      )
    ).to be(false)
  end

  it 'rejects a report whose sender domain does not match the RT originator' do
    message = fixture_with_json('x_arf_json_v3') do |data|
      data.fetch('ReporterInfo')['ReporterOrgDomain'] = 'example.test'
    end

    expect(parse_message(message, assignments: ['10.42.9.42'])).to be_empty
  end

  it 'rejects Netcraft reports with inconsistent sender identity' do
    mutations = [
      proc do |data|
        data.fetch('ReporterInfo')['ReporterOrgDomain'] = 'example.test'
      end,
      proc do |data|
        data.fetch('ReporterInfo')['ReporterOrgEmail'] = 'other@netcraft.com'
      end,
      proc do |data|
        data.fetch('Report')['ReporterCaseID'] = '87654321'
      end
    ]

    mutations.each do |mutation|
      message = fixture_with_json('x_arf_json_v1_netcraft', &mutation)

      expect(parse_message(message, assignments: ['10.42.9.43'])).to be_empty
    end
  end

  it 'rejects a non-legacy report from the Netcraft originator' do
    message = fixture_message('x_arf_json_v4')
    message['X-RT-Originator'].value =
      'takedown-response+12345678@netcraft.com'

    expect(parse_message(message, assignments: ['2001:db8::42'])).to be_empty
  end

  it 'rejects a Netcraft v1 report from the Abusix originator' do
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.fetch('ReporterInfo')['ReporterOrgDomain'] = 'abusix.com'
    end
    message['X-RT-Originator'].value = 'support@abusix.com'

    expect(parse_message(message, assignments: ['10.42.9.43'])).to be_empty
  end

  it 'rejects an Abusix v3 report from a Netcraft originator' do
    message = fixture_message('x_arf_json_v3')
    message['X-RT-Originator'].value =
      'takedown-response+12345678@netcraft.com'

    expect(parse_message(message, assignments: ['10.42.9.42'])).to be_empty
  end

  it 'supports disabling Netcraft sender identity checks' do
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.fetch('ReporterInfo')['ReporterOrgDomain'] = 'example.test'
      data.fetch('ReporterInfo')['ReporterOrgEmail'] = 'other@example.test'
      data.fetch('Report')['ReporterCaseID'] = '87654321'
    end
    original_check_sender = ENV.fetch('CHECK_SENDER', nil)
    ENV['CHECK_SENDER'] = '0'

    incidents = parse_message(message, assignments: ['10.42.9.43'])

    expect(incidents.size).to eq(1)
  ensure
    ENV['CHECK_SENDER'] = original_check_sender
  end

  it 'rejects Netcraft reports outside the forwarding policy' do
    mutations = [
      proc { |data| data.fetch('Report')['ReportSubType'] = 'Trap' },
      proc { |data| data['Disclosure'] = false }
    ]

    mutations.each do |mutation|
      message = fixture_with_json('x_arf_json_v1_netcraft', &mutation)

      expect(parse_message(message, assignments: ['10.42.9.43'])).to be_empty
    end
  end

  it 'rejects undisclosed Netcraft content reports' do
    message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
      data['Disclosure'] = false
    end

    expect(parse_message(message, assignments: ['10.42.9.44'])).to be_empty
  end

  it 'rejects Netcraft content reports with an inconsistent sender identity' do
    message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
      data.fetch('ReporterInfo')['ReporterOrgEmail'] =
        'takedown-response+87654321@netcraft.com'
    end

    expect(parse_message(message, assignments: ['10.42.9.44'])).to be_empty
  end

  it 'rejects Netcraft content reports without a safe absolute HTTP URL' do
    invalid_urls = [
      nil,
      '/relative/path',
      'ftp://files.example.test/payload',
      'https://user@example.test/phishing',
      'https://:/phishing',
      'https://./phishing',
      'https://example.test../phishing',
      'https://example.test:0/phishing',
      'https://example.test:99999/phishing',
      "https://example.test/phishing\nforged",
      "https://example.test/#{'x' * described_class::NETCRAFT_SOURCE_URL_MAX_BYTES}"
    ]

    invalid_urls.each do |source_url|
      message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
        if source_url.nil?
          data.fetch('Report').delete('SourceUrl')
        else
          data.fetch('Report')['SourceUrl'] = source_url
        end
      end

      expect(parse_message(message, assignments: ['10.42.9.44'])).to be_empty
    end
  end

  it 'rejects unsafe or oversized Netcraft content report types' do
    invalid_types = [
      'x' * (described_class::NETCRAFT_CONTENT_TYPE_MAX_CHARACTERS + 1),
      "Phishing\nForged field",
      ' Phishing',
      "\u00a0",
      "Phishing\u00a0"
    ]

    invalid_types.each do |report_type|
      message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
        data.fetch('Report')['ReportType'] = report_type
      end

      expect(parse_message(message, assignments: ['10.42.9.44'])).to be_empty
    end
  end

  it 'rejects Netcraft case IDs longer than the provider limit' do
    case_id = '1' * 33
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.fetch('ReporterInfo')['ReporterOrgEmail'] =
        "takedown-response+#{case_id}@netcraft.com"
      data.fetch('Report')['ReporterCaseID'] = case_id
    end
    message['X-RT-Originator'].value =
      "takedown-response+#{case_id}@netcraft.com"

    expect(parse_message(message, assignments: ['10.42.9.43'])).to be_empty
  end

  it 'does not create a duplicate incident for a Netcraft reminder' do
    assignment = register_assignment('10.42.9.43')
    subject = 'Netcraft issue 12345678: Extortion Mail Server at 10.42.9.43'
    detected_at = Time.utc(2026, 9, 8, 15, 42, 14)
    existing = IncidentReport.new(
      id: 4001,
      user_id: assignment.user_id,
      vps_id: assignment.vps_id,
      ip_address_assignment: assignment,
      subject: subject,
      text: 'Previously persisted incident',
      detected_at: detected_at
    )
    IncidentReport.existing_report = existing

    reminder = fixture_message('x_arf_json_v1_netcraft')
    reminder.subject = '[rt.vpsfree.cz #20004] Re: Issue 12345678: Server involved in fraud at 10.42.9.43'
    incidents = described_class.new(mailbox, reminder, dry_run: true).parse

    expect(incidents).to be_empty
    expect(IncidentReport.where_calls.last).to eq(
      user_id: existing.user_id,
      vps_id: existing.vps_id,
      ip_address_assignment_id: existing.ip_address_assignment_id,
      subject: subject,
      detected_at: detected_at
    )
  end

  it 'does not create a duplicate incident for a Netcraft content reminder' do
    assignment = register_assignment('10.42.9.44')
    subject = 'Netcraft issue 23456789: Phishing at 10.42.9.44'
    detected_at = Time.utc(2026, 9, 9, 10, 15, 0)
    existing = IncidentReport.new(
      id: 4002,
      user_id: assignment.user_id,
      vps_id: assignment.vps_id,
      ip_address_assignment: assignment,
      subject: subject,
      text: 'Previously persisted content incident',
      detected_at: detected_at
    )
    IncidentReport.existing_report = existing

    reminder = fixture_message('x_arf_json_v1_netcraft_content')
    reminder.subject = '[rt.vpsfree.cz #20006] Re: Issue 23456789: Phishing attack'
    incidents = described_class.new(mailbox, reminder, dry_run: true).parse

    expect(incidents).to be_empty
    expect(IncidentReport.where_calls.last).to eq(
      user_id: existing.user_id,
      vps_id: existing.vps_id,
      ip_address_assignment_id: existing.ip_address_assignment_id,
      subject: subject,
      detected_at: detected_at
    )
  end

  it 'rejects XARF report types outside the forwarding policy' do
    message = fixture_with_json('x_arf_json_v3') do |data|
      data.fetch('Report')['ReportType'] = 'LoginAttack'
    end

    expect(parse_message(message, assignments: ['10.42.9.42'])).to be_empty
  end

  it 'rejects v4 user complaints sent over non-SMTP protocols' do
    message = fixture_with_json('x_arf_json_v4') do |data|
      data['protocol'] = 'sms'
      data['evidence_source'] = 'user_complaint'
      data.delete('smtp_from')
      data.delete('source_port')
    end

    expect(parse_message(message, assignments: ['2001:db8::42'])).to be_empty
  end

  it 'rejects reports without supported textual evidence' do
    message = fixture_with_json('x_arf_json_v3') do |data|
      data.dig('Report', 'Sample')['ContentType'] = 'image/png'
    end

    expect(parse_message(message, assignments: ['10.42.9.42'])).to be_empty
  end

  it 'rejects Netcraft reports without supported textual evidence' do
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.dig('Report', 'Samples').first['ContentType'] = 'image/png'
    end

    expect(parse_message(message, assignments: ['10.42.9.43'])).to be_empty
  end

  it 'rejects Netcraft reports containing mixed textual and binary evidence' do
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.dig('Report', 'Samples') << {
        'ContentType' => 'image/png',
        'Payload' => ['synthetic binary evidence'].pack('m0'),
        'Base64Encoded' => true
      }
    end

    expect(parse_message(message, assignments: ['10.42.9.43'])).to be_empty
  end

  it 'rejects Netcraft reports containing empty textual evidence' do
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.dig('Report', 'Samples').first['Payload'] = ['   '].pack('m0')
    end

    expect(parse_message(message, assignments: ['10.42.9.43'])).to be_empty
  end

  it 'includes optional textual evidence from Netcraft content reports' do
    message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
      data.fetch('Report')['Samples'] = [
        {
          'ContentType' => 'text/plain',
          'Payload' => ['Synthetic content evidence'].pack('m0'),
          'Base64Encoded' => true
        }
      ]
    end

    incidents = parse_message(message, assignments: ['10.42.9.44'])

    expect(incidents.size).to eq(1)
    expect(incidents.first.text).to include(
      "Reported evidence:\n\nSynthetic content evidence"
    )
  end

  it 'rejects binary evidence from Netcraft content reports' do
    message = fixture_with_json('x_arf_json_v1_netcraft_content') do |data|
      data.fetch('Report')['Samples'] = [
        {
          'ContentType' => 'image/png',
          'Payload' => ['Synthetic binary evidence'].pack('m0'),
          'Base64Encoded' => true
        }
      ]
    end

    expect(parse_message(message, assignments: ['10.42.9.44'])).to be_empty
  end

  it 'rejects Netcraft incident text that exceeds database capacity' do
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.fetch('Report')['ReporterNotes'] =
        'x' * described_class::MAX_TEXT_BYTES
    end

    incidents = parse_message(
      message,
      assignments: ['10.42.9.43'],
      dry_run: false
    )

    expect(incidents).to be_empty
    expect(IncidentReport.records).to be_empty
  end

  it 'rejects characters unsupported by the incident table encoding' do
    message = fixture_with_json('x_arf_json_v1_netcraft') do |data|
      data.fetch('Report')['ReporterNotes'] = 'Unsupported character: 💥'
    end

    incidents = parse_message(
      message,
      assignments: ['10.42.9.43'],
      dry_run: false
    )

    expect(incidents).to be_empty
    expect(IncidentReport.records).to be_empty
  end

  it 'rejects malformed JSON attachments' do
    message = fixture_message('x_arf_json_v3')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    attachment.body = '{'
    attachment.content_transfer_encoding = '8bit'

    expect(parse_message(message, assignments: ['10.42.9.42'])).to be_empty
  end
end
