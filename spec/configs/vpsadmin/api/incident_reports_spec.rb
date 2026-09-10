# frozen_string_literal: true

require 'require_all'

require_relative '../../../../configs/vpsadmin/api/incident_reports'

RSpec.describe VpsAdmin::API::IncidentReports do
  it 'routes a recognized Request Tracker message to its parser' do
    register_assignment('10.42.9.42')

    result = described_class.handle_message(
      mailbox,
      fixture_message('fail2ban'),
      dry_run: true
    )

    expect(result).to be_processed
    expect(result.reply).to eq(
      from: 'vpsadmin@vpsfree.cz',
      to: ['abuse-komentare@vpsfree.cz']
    )
    expect(result.incidents.size).to eq(1)
    expect(result.incidents.first.subject).to eq('Automatic abuse report for IP address 10.42.9.42')
  end

  it 'routes a prose UCEPROTECT notification to the MasterDC parser' do
    register_assignment('192.168.65.61')

    result = described_class.handle_message(
      mailbox,
      fixture_message('masterdc_uceprotect_plain'),
      dry_run: true
    )

    expect(result).to be_processed
    expect(result.incidents.size).to eq(1)
    expect(result.incidents.first.subject).to eq(
      '[MasterDC support #805648] UCEPROTECT Monitoring Report: IP 192.168.65.61'
    )
  end

  it 'routes an XARF JSON report by its MIME content' do
    register_assignment('10.42.9.42')

    result = described_class.handle_message(
      mailbox,
      fixture_message('x_arf_json_v3'),
      dry_run: true
    )

    expect(result).to be_processed
    expect(result.incidents.size).to eq(1)
    expect(result.incidents.first.subject).to eq('Spam report for 10.42.9.42')
  end

  it 'routes a Netcraft XARF v1 report by its MIME content' do
    register_assignment('10.42.9.43')

    result = described_class.handle_message(
      mailbox,
      fixture_message('x_arf_json_v1_netcraft'),
      dry_run: true
    )

    expect(result).to be_processed
    expect(result.incidents.size).to eq(1)
    expect(result.incidents.first.subject).to eq(
      'Netcraft issue 12345678: Extortion Mail Server at 10.42.9.43'
    )
  end

  it 'routes a Netcraft XARF v1 content report by its MIME content' do
    register_assignment('10.42.9.44')

    result = described_class.handle_message(
      mailbox,
      fixture_message('x_arf_json_v1_netcraft_content'),
      dry_run: true
    )

    expect(result).to be_processed
    expect(result.incidents.size).to eq(1)
    expect(result.incidents.first.subject).to eq(
      'Netcraft issue 23456789: Phishing at 10.42.9.44'
    )
  end

  it 'processes a duplicate Netcraft reminder without another incident' do
    register_assignment('10.42.9.43')
    first = AbuseNoticeParser::XArfJson.new(
      mailbox,
      fixture_message('x_arf_json_v1_netcraft'),
      dry_run: true
    ).parse.first
    first.id = 4001
    IncidentReport.existing_report = first

    reminder = fixture_message('x_arf_json_v1_netcraft')
    reminder.subject = '[rt.vpsfree.cz #20004] Re: Issue 12345678: Server involved in fraud at 10.42.9.43'
    result = described_class.handle_message(mailbox, reminder, dry_run: true)

    expect(result).to be_processed
    expect(result.incidents).to be_empty
  end

  it 'leaves a Netcraft report with mismatched identity unidentified' do
    message = fixture_message('x_arf_json_v1_netcraft')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    data = JSON.parse(attachment.decoded)
    data.fetch('ReporterInfo')['ReporterOrgEmail'] = 'other@netcraft.com'
    attachment.body = JSON.generate(data)
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end

  it 'leaves a Netcraft v1 report from the Abusix originator unidentified' do
    message = fixture_message('x_arf_json_v1_netcraft')
    message['X-RT-Originator'].value = 'support@abusix.com'
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    data = JSON.parse(attachment.decoded)
    data.fetch('ReporterInfo')['ReporterOrgDomain'] = 'abusix.com'
    attachment.body = JSON.generate(data)
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end

  it 'leaves a malformed Netcraft report unidentified' do
    message = fixture_message('x_arf_json_v1_netcraft')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    attachment.body = '{'
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end

  it 'leaves a Netcraft content report with an unsafe URL unidentified' do
    message = fixture_message('x_arf_json_v1_netcraft_content')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    data = JSON.parse(attachment.decoded)
    data.fetch('Report')['SourceUrl'] = 'https://./phishing'
    attachment.body = JSON.generate(data)
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end

  it 'leaves malformed Netcraft content evidence unidentified' do
    message = fixture_message('x_arf_json_v1_netcraft_content')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    data = JSON.parse(attachment.decoded)
    data.fetch('Report')['Samples'] = false
    attachment.body = JSON.generate(data)
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end

  it 'leaves invalid Unicode in Netcraft content metadata unidentified' do
    message = fixture_message('x_arf_json_v1_netcraft_content')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    attachment.body = attachment.decoded.sub('Phishing', '\\udfff')
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end

  it 'leaves a malformed v1 report from the Abusix originator unidentified' do
    message = fixture_message('x_arf_json_v1_netcraft_content')
    message['X-RT-Originator'].value = 'support@abusix.com'
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    data = JSON.parse(attachment.decoded)
    data.fetch('Report')['SourceUrl'] = ''
    attachment.body = JSON.generate(data)
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end

  it 'preserves handling of malformed Abusix reports' do
    message = fixture_message('x_arf_json_v3')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    attachment.body = '{'
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).to be_processed
    expect(result.incidents).to be_empty
  end

  it 'preserves handling of oversized Abusix reports' do
    message = fixture_message('x_arf_json_v3')
    attachment = message.attachments.find { |part| part.filename == 'xarf.json' }
    attachment.body = 'x' * (AbuseNoticeParser::XArfJson::MAX_JSON_BYTES + 1)
    attachment.content_transfer_encoding = '8bit'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).to be_processed
    expect(result.incidents).to be_empty
  end

  it 'does not route recognized subjects from unexpected senders by default' do
    message = fixture_message('fail2ban')
    message['X-RT-Originator'].value = 'attacker@example.test'

    result = described_class.handle_message(mailbox, message, dry_run: true)

    expect(result).not_to be_processed
    expect(result.incidents).to be_empty
  end
end
