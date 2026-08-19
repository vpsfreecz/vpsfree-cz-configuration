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

  def parse_message(message, assignments: [])
    assignments.each { |ip| register_assignment(ip) }
    described_class.new(mailbox, message, dry_run: true).parse
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

  it 'rejects malformed JSON attachments' do
    message = fixture_message('x_arf_json_v3')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    attachment.body = '{'
    attachment.content_transfer_encoding = '8bit'

    expect(parse_message(message, assignments: ['10.42.9.42'])).to be_empty
  end
end
