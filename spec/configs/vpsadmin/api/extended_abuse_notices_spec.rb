# frozen_string_literal: true

require_relative '../../../../configs/vpsadmin/api/incident_reports'

RSpec.describe VpsAdmin::API::IncidentReports, '.handle_message' do
  routes = {
    'blocklist' => '2026-09-28T08:41:50Z',
    'provider_tools' => '2026-09-28T08:44:40.114Z',
    'burina_first' => '2026-09-28T09:23:02Z',
    'lrob' => '2026-09-28T09:29:00Z',
    'cedo' => '2026-09-28T09:36:08Z',
    'burina_second' => '2026-09-28T10:32:52Z',
    'cisilino' => '2026-09-28T10:38:19Z',
    'burina_third' => '2026-09-28T11:46:46Z',
    'custom_visuals' => '2026-09-28T11:57:11.439254Z'
  }

  def handle(mail, dry_run: true)
    VpsAdmin::API::IncidentReports.handle_message(mailbox, mail, dry_run: dry_run)
  end

  def primary_part(mail)
    mail.multipart? ? mail.parts.find { |part| part.filename.nil? && part.mime_type == 'text/plain' } : mail
  end

  def rewrite_part(part)
    part.body = yield(part.decoded.gsub("\r\n", "\n"))
    part.content_transfer_encoding = '8bit'
  end

  def rewrite_body(mail)
    rewrite_part(primary_part(mail)) do |text|
      lines = text.lines
      marker = lines.index { |line| line.lstrip.start_with?('Ticket <URL: ') }
      "#{lines.take(marker + 1).join}\n#{yield(lines.drop(marker + 1).join)}"
    end
  end

  def rewrite_report(mail, &)
    rewrite_part(mail.parts.find { |part| part.filename == 'report.txt' }, &)
  end

  def rewrite_json(mail)
    part = mail.parts.find { |item| item.filename == 'xarf.json' }
    data = JSON.parse(part.decoded)
    yield(data)
    part.body = JSON.generate(data)
    part.content_transfer_encoding = '8bit'
  end

  def readable_body(mail)
    primary_part(mail).decoded.gsub("\r\n", "\n").lines
                      .drop_while { |line| !line.lstrip.start_with?('Ticket <URL: ') }
                      .drop(1).join.strip
  end

  def expected_fixture_text(mail)
    sections = [readable_body(mail)]
    if mail.multipart?
      sections.concat(mail.parts.filter_map do |part|
        next if part.equal?(primary_part(mail)) || part.mime_type != 'text/plain'

        part.decoded.gsub("\r\n", "\n").strip
      end)
    end
    json = mail.parts.find { |part| part.filename == 'xarf.json' }
    if json
      sections.concat(JSON.parse(json.decoded).fetch('evidence', []).map do |item|
        item.fetch('payload').unpack1('m0').gsub("\r\n", "\n").strip
      end)
    end
    sections.reject(&:empty?).join("\n\n")
  end

  def add_syslog_record(mail, record)
    rewrite_body(mail) do |text|
      text.sub(/(^Lines containing failures of [^\n]+\n)/, "\\1#{record}\n")
    end
  end

  def replace_syslog_records(mail, records)
    rewrite_body(mail) { |text| text.sub(/(^Lines containing failures of [^\n]+\n).*\z/m, "\\1#{records}\n") }
  end

  before { register_assignment('192.0.2.10') }

  routes.each do |name, expected|
    it "preserves #{name} content and subject with one event-time lookup in a dry run" do
      mail = fixture_message(name)
      original = mail.to_s
      expected_text = expected_fixture_text(mail)
      result = handle(mail)

      expect(result).to be_processed
      expect(result.incidents.size).to eq(1)
      incident = result.incidents.first
      expect(incident.detected_at).to eq(Time.iso8601(expected))
      expect(incident.subject).to eq(mail.subject.sub(/\A\[rt\.vpsfree\.cz #\d+\] /, ''))
      expect(incident.text).to eq(expected_text)
      expect(incident.saved).to be(false)
      expect(IncidentReport.records).to be_empty
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq(
        [{ addr_str: '192.0.2.10', time: Time.iso8601(expected) }]
      )
      expect(mail.to_s).to eq(original)
    end
  end

  %w[blocklist provider_tools lrob cedo cisilino custom_visuals].each do |name|
    it "rejects #{name} from a mismatched RT originator" do
      mail = fixture_message(name)
      mail['X-RT-Originator'].value = 'untrusted@example.test'
      result = handle(mail)
      expect(result).not_to be_processed
      expect(result.incidents).to be_empty
    end
  end

  it 'honors CHECK_SENDER bypass while retaining required source consistency' do
    mail = fixture_message('provider_tools')
    mail['X-RT-Originator'].value = 'untrusted@example.test'
    previous = ENV.fetch('CHECK_SENDER', nil)
    ENV['CHECK_SENDER'] = 'no'
    expect(handle(mail).incidents.size).to eq(1)
    rewrite_body(mail) { |text| text.sub('IP: 192.0.2.10', 'IP: 198.51.100.20') }
    expect(handle(mail).incidents).to be_empty
  ensure
    previous.nil? ? ENV.delete('CHECK_SENDER') : ENV['CHECK_SENDER'] = previous
  end

  it 'saves one incident per report without deduplicating overlapping Burina reports' do
    incidents = %w[burina_first burina_second burina_third].flat_map do |name|
      handle(fixture_message(name), dry_run: false).incidents
    end
    expect(incidents.size).to eq(3)
    expect(IncidentReport.records).to eq(incidents)
    expect(incidents.map(&:saved)).to eq([true, true, true])
  end

  it 'keeps Apache abuse notices on the legacy route when they include a numeric timezone note' do
    register_assignment('10.42.9.42')
    mail = fixture_message('access_log_abuse')
    rewrite_body(mail) do |text|
      text.sub('Lines containing failures of', "Note: Local timezone is +0200 (CEST)\n\nLines containing failures of")
    end
    result = handle(mail)
    expect(result).to be_processed
    expect(result.incidents.size).to eq(1)
    incident = result.incidents.first
    expect(incident.detected_at).to eq(Time.utc(2026, 4, 19, 5, 18, 38))
    expect(incident.subject).to eq('Abuse from 10.42.9.42')
    expect(incident.text).to eq(readable_body(mail))
    expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq(
      [{ addr_str: '10.42.9.42', time: Time.utc(2026, 4, 19, 5, 18, 38) }]
    )
    expect(incident.saved).to be(false)
    expect(IncidentReport.records).to be_empty
  end

  it 'preserves wrapping and other-IP logs without interpreting SSH wording' do
    mail = fixture_message('burina_first')
    record = 'Sep 28 11:23:10 host.example.test arbitrary-service: Unknown wording from 192.0.2.20, user from 192.0.2.10'
    add_syslog_record(mail, record)
    incident = handle(mail).incidents.first
    expect(incident.detected_at).to eq(Time.utc(2026, 9, 28, 9, 23, 10))
    expect(incident.text).to include(record, 'unrelatedsynthetic', '192.0.2.20')
    expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq(
      [{ addr_str: '192.0.2.10', time: Time.utc(2026, 9, 28, 9, 23, 10) }]
    )
  end

  it 'preserves a wrapped Custom Visuals record with unknown wording and another log IP' do
    mail = fixture_message('custom_visuals')
    rewrite_body(mail) { |text| text.sub('Failed password', 'Unknown SSH wording').sub('for synthetic from 192.0.2.10', 'for synthetic from 192.0.2.20') }
    incident = handle(mail).incidents.first
    expect(incident.text).to eq(readable_body(mail))
    expect(incident.text).to include("Unknown SSH wording\nfor synthetic from 192.0.2.20")
    expect(incident.detected_at).to eq(Time.iso8601('2026-09-28T11:57:11.439254Z'))
    expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups.first[:addr_str]).to eq('192.0.2.10')
  end

  it 'preserves date-only wrapped Custom Visuals text without treating it as another event' do
    mail = fixture_message('custom_visuals')
    rewrite_body(mail) { |text| text.sub('for synthetic from', "2026-09-28 opaque wrapped date\nfor synthetic from") }
    incident = handle(mail).incidents.first
    expect(incident.text).to eq(readable_body(mail))
    expect(incident.text).to include('2026-09-28 opaque wrapped date')
    expect(incident.detected_at).to eq(Time.iso8601('2026-09-28T11:57:11.439254Z'))
    expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups.size).to eq(1)
  end

  it 'normalizes CRLF in quoted-printable bodies and preserves all readable sections' do
    %w[cisilino lrob cedo].each do |name|
      mail = fixture_message(name)
      part = primary_part(mail)
      part.body = Mail::Encodings::QuotedPrintable.encode(part.decoded.gsub("\r\n", "\n").gsub("\n", "\r\n"))
      part.content_transfer_encoding = 'quoted-printable'
      expect(handle(mail).incidents.first.text).to eq(expected_fixture_text(mail))
    end
  end

  it 'preserves forwarding-like prose but ignores HTML, binary and nested MIME content' do
    mail = fixture_message('blocklist')
    rewrite_body(mail) { |text| "Begin forwarded message:\nFrom: synthetic@example.test\nSubject: original prose\n#{text}" }
    mail.add_part(Mail::Part.new do
      content_type 'text/html'
      body '<p>HTML must remain outside the incident</p>'
    end)
    mail.add_file(filename: 'binary.bin', content: 'BINARY NOT INCLUDED')
    forwarded = Mail.new do
      content_type 'text/plain'
      body 'NESTED NOT INCLUDED'
    end
    mail.add_part(Mail::Part.new do
      content_type 'message/rfc822'
      body forwarded.to_s
    end)
    incident = handle(mail).incidents.first
    expect(incident.text).to include('Begin forwarded message:', 'From: synthetic@example.test', 'Subject: original prose')
    expect(incident.text).not_to include('HTML must remain', 'BINARY NOT INCLUDED', 'NESTED NOT INCLUDED')
  end

  it 'avoids repeating an identical direct plain attachment' do
    mail = fixture_message('blocklist')
    report = mail.attachments.find { |part| part.filename == 'report.txt' }.decoded
    mail.add_file(filename: 'duplicate.txt', content: report)
    text = handle(mail).incidents.first.text
    expect(text.scan('Reported-From: abuse-team@blocklist.de').size).to eq(1)
  end

  describe 'authoritative required metadata' do
    it 'accepts RFC or ISO dates with fractions independently of unused subject dates or logs' do
      %w[blocklist cedo].each do |name|
        mail = fixture_message(name)
        rewrite_report(mail) { |text| text.sub(/^Date: .+$/, 'Date: 2026-09-28T10:41:50.123456+0200') }
        mail.subject = mail.subject.sub(/ - .+$/, ' - invalid subject date')
        expect(handle(mail).incidents.first.detected_at).to eq(Time.iso8601('2026-09-28T08:41:50.123456Z'))
      end
    end

    it 'ignores missing or invalid service/port/report ID and opaque structured log text' do
      mail = fixture_message('cedo')
      rewrite_report(mail) do |text|
        "#{text.lines.grep_v(/\A(?:Service|Port|Report-ID):/).join}Optional prose without a field separator\n"
      end
      rewrite_part(mail.parts.find { |part| part.filename == 'logfile.log' }) { "Unfamiliar log syntax for 192.0.2.20\nFeb 30 invalid log timestamp\n" }
      incident = handle(mail).incidents.first
      expect(incident.detected_at).to eq(Time.utc(2026, 9, 28, 9, 36, 8))
      expect(incident.text).to include('Optional prose without a field separator', 'Feb 30 invalid log timestamp')
    end

    it 'accepts Blocklist empty log headings and CEDO reports without optional logs' do
      expect(handle(fixture_message('blocklist')).incidents.size).to eq(1)
      mail = fixture_message('cedo')
      mail.parts.delete(mail.parts.find { |part| part.filename == 'logfile.log' })
      expect(handle(mail).incidents.first.text).to include('Source: 192.0.2.10')
    end

    it 'ignores Provider.tools generation dates, ranges, category repetition, state and services' do
      mail = fixture_message('provider_tools')
      rewrite_body(mail) do |text|
        text.sub(/^Date: .+$/, "Date: invalid\nDate: still invalid")
            .sub(/^  First seen: .+$/, "  First seen: reversed\n  First seen: invalid")
            .sub(/^  Category: .+$/, "  Category: arbitrary\n  Category: different")
            .sub(/^  State: .+$/, '  State: arbitrary original text')
            .sub(/^  Services: .+$/, '  Services: unknown')
      end
      incident = handle(mail).incidents.first
      expect(incident.detected_at).to eq(Time.iso8601('2026-09-28T08:44:40.114Z'))
      expect(incident.text).to eq(readable_body(mail))
      mail = fixture_message('provider_tools')
      rewrite_body(mail) { |text| text.lines.grep_v(/\A(?:Date|  First seen|  Category|  State|  Services):/).join }
      expect(handle(mail).incidents.size).to eq(1)
    end

    [nil, [], {}, 123, true, false, 'invalid', '2026-09-29T09:29:00Z'].each do |value|
      it "ignores unused LRob range extensions of type #{value.class}" do
        mail = fixture_message('lrob')
        rewrite_json(mail) do |data|
          data['first_seen'] = value
          data['last_seen'] = value
        end
        expect(handle(mail).incidents.first.detected_at).to eq(Time.utc(2026, 9, 28, 9, 29))
      end
    end

    it 'preserves opaque LRob textual evidence in order without raw JSON or Base64 data' do
      mail = fixture_message('lrob')
      payloads = ["Earlier record with 192.0.2.20\nunknown SSH syntax\n", "Second payload\nwith internal wrapping\n"]
      rewrite_json(mail) do |data|
        data['first_seen'] = 'invalid'
        data['last_seen'] = nil
        data['evidence'] = payloads.map { |payload| { 'content_type' => 'text/plain', 'payload' => [payload].pack('m0') } }
      end
      rewrite_body(mail) { |text| text.sub('2026-09-28 09:29:00', 'invalid prose date').sub('Detected attacking IP: 192.0.2.10', 'Detected attacking IP: 198.51.100.20') }
      incident = handle(mail).incidents.first
      expect(incident.text).to eq([readable_body(mail), *payloads.map(&:strip)].join("\n\n"))
      expect(incident.text).not_to include('"xarf_version"', [payloads.first].pack('m0'))
    end

    it 'accepts empty LRob evidence and absent optional ranges' do
      mail = fixture_message('lrob')
      rewrite_json(mail) do |data|
        data['evidence'] = []
        data.delete('first_seen')
        data.delete('last_seen')
      end
      expect(handle(mail).incidents.first.text).to eq(readable_body(mail))
    end

    it 'uses only the Cisilino subject IP slots and English Last seen' do
      mail = fixture_message('cisilino')
      rewrite_body(mail) { "Last seen: 2026-09-28 10:38:19 UTC\nUnknown sample wording for 192.0.2.20\n" }
      incident = handle(mail).incidents.first
      expect(incident.text).to eq(readable_body(mail))
      expect(incident.detected_at).to eq(Time.utc(2026, 9, 28, 10, 38, 19))
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups.size).to eq(1)
    end

    it 'uses the Custom Visuals last-record prefix without prose dates, counts or timezone notes' do
      mail = fixture_message('custom_visuals')
      rewrite_body(mail) do
        "The log line for the last record is:\n2026-09-28 06:57:11.439254-0500 opaque original\nwrapped record from 192.0.2.20\n"
      end
      incident = handle(mail).incidents.first
      expect(incident.text).to eq(readable_body(mail))
      expect(incident.detected_at).to eq(Time.iso8601('2026-09-28T11:57:11.439254Z'))
    end
  end

  describe 'required-metadata rejections' do
    it 'rejects duplicate source/date fields and competing required MIME parts without fallback' do
      %w[Source Date].each do |field|
        mail = fixture_message('cedo')
        rewrite_report(mail) { |text| "#{text}#{field}: invalid\n" }
        result = handle(mail)
        expect(result).not_to be_processed
        expect(result.incidents).to be_empty
      end
      mail = fixture_message('blocklist')
      mail.add_file(filename: 'report.txt', content: mail.attachments.find { |part| part.filename == 'report.txt' }.decoded)
      expect(handle(mail).incidents).to be_empty
    end

    it 'rejects missing required or nested report attachments and competing primary sections' do
      mail = fixture_message('blocklist')
      report = mail.parts.find { |part| part.filename == 'report.txt' }
      mail.parts.delete(report)
      forwarded = Mail.new
      forwarded.add_part(report)
      mail.add_part(Mail::Part.new do
        content_type 'message/rfc822'
        body forwarded.to_s
      end)
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('blocklist')
      mail.add_part(Mail::Part.new do
        content_type 'text/plain'
        body 'another primary section'
      end)
      expect(handle(mail).incidents).to be_empty
    end

    it 'rejects required attachment MIME types and unsupported profile admission' do
      mail = fixture_message('cedo')
      mail.parts.find { |part| part.filename == 'report.txt' }.content_type = 'text/html'
      expect(handle(mail).incidents).to be_empty
      %w[Version Category Report-Type Source-Type].each do |field|
        mail = fixture_message('blocklist')
        rewrite_report(mail) { |text| text.sub(/^#{field}: .+$/, "#{field}: unsupported") }
        expect(handle(mail).incidents).to be_empty
      end
    end

    it 'rejects missing, conflicting or non-host source claims without arbitrary IP extraction' do
      ['invalid.example.test', '192.0.2.10/32', '198.51.100.20', ''].each do |source|
        mail = fixture_message('blocklist')
        rewrite_report(mail) { |text| text.sub('Source: 192.0.2.10', "Source: #{source}") }
        expect(handle(mail).incidents).to be_empty
      end
      mail = fixture_message('cisilino')
      mail.subject = mail.subject.sub('/ Segnalazione abuso - IP 192.0.2.10', '/ Segnalazione abuso - IP 198.51.100.20')
      expect(handle(mail).incidents).to be_empty
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to be_empty
    end

    it 'rejects invalid selected structured dates without subject or log-date fallback' do
      ['invalid', '2026-02-30T08:41:50Z', '2026-09-28T08:41:50', 'Mon, 28 Sep 2026 10:41:50 CEST'].each do |date|
        mail = fixture_message('blocklist')
        rewrite_report(mail) { |text| text.sub(/^Date: .+$/, "Date: #{date}") }
        expect(handle(mail).incidents).to be_empty
      end
    end

    it 'rejects Provider.tools required source/type/time inconsistencies and competing blocks' do
      changes = [
        ->(text) { text.sub('  IP: 192.0.2.10', '  IP: 198.51.100.20') },
        ->(text) { text.sub('Report-Type: Abuse/Policy', 'Report-Type: arbitrary') },
        ->(text) { text.sub('2026-09-28T08:44:40.114Z', 'invalid') },
        ->(text) { text.sub('  Last seen:', "  Last seen: invalid\n  Last seen:") },
        ->(text) { "#{text}\nX-XARF: PLAIN\nSource: 192.0.2.10\n" }
      ]
      changes.each do |change|
        mail = fixture_message('provider_tools')
        rewrite_body(mail, &change)
        expect(handle(mail).incidents).to be_empty
      end
    end

    it 'rejects malformed, duplicated or competing LRob JSON attachments and metadata' do
      mail = fixture_message('lrob')
      rewrite_part(mail.attachments.first) { '{' }
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('lrob')
      rewrite_part(mail.attachments.first) { |json| json.sub('"type":', '"type":"login_attack", "type":') }
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('lrob')
      rewrite_part(mail.attachments.first) { |json| json.sub('"first_seen":', '"first_seen":null, "first_seen":') }
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('lrob')
      mail.add_file(filename: 'xarf.json', content: mail.attachments.first.decoded)
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('lrob')
      mail.attachments.first.content_type = 'text/plain'
      expect(handle(mail).incidents).to be_empty
    end

    it 'retains LRob identity, source, selected timestamp, Base64 and evidence-type validation' do
      changes = [
        ->(data) { data.fetch('reporter')['contact'] = 'other@lrob.net' },
        ->(data) { data['type'] = 'spam' },
        ->(data) { data['source_identifier'] = '198.51.100.20' },
        ->(data) { data['timestamp'] = 'invalid' },
        ->(data) { data['timestamp'] = [] },
        ->(data) { data.fetch('evidence').first['payload'] = '**' },
        ->(data) { data.fetch('evidence').first['content_type'] = 'application/octet-stream' }
      ]
      changes.each do |change|
        mail = fixture_message('lrob')
        rewrite_json(mail, &change)
        result = handle(mail, dry_run: false)
        expect(result).not_to be_processed
        expect(result.incidents).to be_empty
        expect(IncidentReport.records).to be_empty
      end
      expect(handle(fixture_message('lrob')).incidents.size).to eq(1)
    end

    it 'rejects missing, repeated or invalid English Cisilino event time' do
      ['', 'Last seen: invalid', "Last seen: 2026-09-28 10:38:19 UTC\nLast seen: 2026-09-28 10:38:19 UTC"].each do |body|
        mail = fixture_message('cisilino')
        rewrite_body(mail) { body }
        expect(handle(mail).incidents).to be_empty
      end
    end

    it 'rejects missing offsets and invalid or competing designated Custom Visuals timestamps' do
      changes = [
        ->(text) { text.sub('06:57:11.439254-0500', '06:57:11.439254') },
        ->(text) { text.sub('2026-09-28 06:57:11.439254', '2026-02-30 06:57:11.439254') },
        ->(text) { text.sub('The log line for the last record is:', 'An arbitrary line:') },
        ->(text) { text.sub('for synthetic from', "2026-09-28 06:57:12.439254-0500 second event\nfor synthetic from") },
        ->(text) { "#{text}\nThe log line for the last record is:\n2026-09-28 06:57:11-0500 second record\n" }
      ]
      changes.each do |change|
        mail = fixture_message('custom_visuals')
        rewrite_body(mail, &change)
        expect(handle(mail).incidents).to be_empty
      end
    end
  end

  describe 'one historical event owner for the complete report' do
    before { AbuseNoticeParserSpec::AssignmentRegistry.reset! }

    it 'preserves earlier-owner and other-IP records for the selected event owner' do
      boundary = Time.utc(2026, 9, 28, 9, 20)
      register_assignment('192.0.2.10', user_id: 1002, to_date: boundary)
      selected = register_assignment('192.0.2.10', user_id: 1003, from_date: boundary)
      mail = fixture_message('burina_first')
      incident = handle(mail).incidents.first
      expect(incident.user_id).to eq(1003)
      expect(incident.ip_address_assignment.id).to eq(selected.id)
      expect(incident.text).to eq(expected_fixture_text(mail))
      expect(incident.text).to include('10:38:31', '192.0.2.20', 'drop connection')
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups.size).to eq(1)
    end

    %w[provider_tools lrob cisilino custom_visuals].each do |name|
      it "accepts #{name} across A/B/A history using only its event assignment" do
        register_assignment('192.0.2.10', to_date: Time.utc(2026, 9, 28, 8, 42))
        register_assignment('192.0.2.10', user_id: 1002, from_date: Time.utc(2026, 9, 28, 8, 42), to_date: Time.utc(2026, 9, 28, 8, 43))
        selected = register_assignment('192.0.2.10', from_date: Time.utc(2026, 9, 28, 8, 43))
        mail = fixture_message(name)
        incident = handle(mail).incidents.first
        expect(incident.ip_address_assignment.id).to eq(selected.id)
        expect(incident.text).to eq(expected_fixture_text(mail))
        expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups.size).to eq(1)
      end
    end

    it 'selects the historical assignment instead of the present owner and accepts exact highest-ID ties' do
      event = Time.utc(2026, 9, 28, 9, 23, 2)
      register_assignment('192.0.2.10', to_date: event)
      selected = register_assignment('192.0.2.10', user_id: 1002, from_date: event, to_date: Time.utc(2026, 9, 28, 10))
      register_assignment('192.0.2.10', user_id: 1003, from_date: Time.utc(2026, 9, 29))
      mail = fixture_message('burina_first')
      incident = handle(mail).incidents.first
      expect(incident.ip_address_assignment.id).to eq(selected.id)
      expect(incident.text).to eq(readable_body(mail))
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq([{ addr_str: '192.0.2.10', time: event }])
    end

    it 'rejects a missing event owner without falling back to a current owner' do
      register_assignment('192.0.2.10', from_date: Time.utc(2026, 9, 29))
      expect(handle(fixture_message('blocklist')).incidents).to be_empty
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups.size).to eq(1)
    end
  end

  describe 'syslog timestamp prefixes' do
    it 'takes the maximum prefix independently of log order' do
      mail = fixture_message('burina_first')
      rewrite_body(mail) do |text|
        header, records = text.split(/(?<=\(max 1000\)\n)/, 2)
        header + records.lines.reverse.join
      end
      expect(handle(mail).incidents.first.detected_at).to eq(Time.utc(2026, 9, 28, 9, 23, 2))
    end

    it 'ignores timestamp-like prose outside the report log section while preserving it' do
      mail = fixture_message('burina_first')
      rewrite_body(mail) do |text|
        "#{text.sub('Lines containing failures', "Sep 28 11:23:13 outside before logs\n\nLines containing failures")}\nSep 28 11:23:13 outside after logs\n"
      end
      incident = handle(mail).incidents.first
      expect(incident.detected_at).to eq(Time.utc(2026, 9, 28, 9, 23, 2))
      expect(incident.text).to include('outside before logs', 'outside after logs')
    end

    it 'infers December in the preceding year and valid leap days' do
      [[2027, 1, 1, 'Dec 31', Time.utc(2026, 12, 31, 9, 23, 2)], [2024, 3, 1, 'Feb 29', Time.utc(2024, 2, 29, 9, 23, 2)]].each do |year, month, day, label, expected|
        mail = fixture_message('burina_first')
        mail.date = Time.new(year, month, day, 0, 10, 0, '+02:00')
        rewrite_body(mail) { |text| text.gsub('Sep 28', label) }
        expect(handle(mail).incidents.first.detected_at).to eq(expected)
      end
    end

    it 'accepts a unique past prefix exactly 31 days old and rejects older records' do
      mail = fixture_message('burina_first')
      event = Time.new(2026, 9, 28, 11, 23, 2, '+02:00')
      mail.date = event + (31 * 86_400)
      replace_syslog_records(mail, 'Sep 28 11:23:02 opaque record without an SSH grammar')
      expect(handle(mail).incidents.first.detected_at).to eq(event)
      mail.date = event + (31 * 86_400) + 1
      expect(handle(mail).incidents).to be_empty
    end

    it 'rejects invalid/future/stale prefixes, missing numeric notes and competing sections' do
      changes = [
        ->(text) { text.gsub('Sep 28', 'Feb 29') },
        ->(text) { text.sub('Sep 28 11:23:02', 'Sep 29 11:23:02') },
        ->(text) { text.sub('Sep 28 11:23:02', 'Sep 28 11:99:02') },
        ->(text) { text.gsub('Sep 28', 'Aug 01') },
        ->(text) { text.sub('Note: Local timezone is +0200 (CEST)', 'Note: Local timezone is CEST') },
        ->(text) { text.sub('Lines containing failures of', 'No recognized log section for') },
        ->(text) { "#{text}\n\nLines containing failures of 192.0.2.20 (max 1000)\nSep 28 11:23:02 second report\n" }
      ]
      changes.each do |change|
        mail = fixture_message('burina_first')
        rewrite_body(mail, &change)
        result = handle(mail)
        expect(result).to be_processed
        expect(result.incidents).to be_empty
      end
    end

    it 'normalizes IPv6 subject sources independently of all log source wording' do
      mail = fixture_message('burina_second')
      mail.subject = mail.subject.sub('192.0.2.10', '2001:db8::10')
      register_assignment('2001:db8::10')
      incident = handle(mail).incidents.first
      expect(incident.text).to include('192.0.2.10')
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups.first[:addr_str]).to eq('2001:db8::10')
    end

    it 'is independent of the process timezone for ISO, RFC and year-inferred reports' do
      previous = ENV.fetch('TZ', nil)
      times = %w[UTC Pacific/Honolulu Asia/Tokyo].map do |timezone|
        ENV['TZ'] = timezone
        %w[blocklist provider_tools burina_first custom_visuals].map { |name| handle(fixture_message(name)).incidents.first.detected_at }
      end
      expect(times.uniq.length).to eq(1)
    ensure
      previous.nil? ? ENV.delete('TZ') : ENV['TZ'] = previous
    end
  end

  describe 'original content and storage bounds' do
    it 'rejects oversized original subjects rather than regenerating or truncating them' do
      mail = fixture_message('blocklist')
      mail.subject = "#{mail.subject} #{'x' * 256}"
      expect(handle(mail, dry_run: false).incidents).to be_empty
      expect(IncidentReport.records).to be_empty
    end

    it 'rejects oversized readable content and utf8mb4 characters before saving' do
      ['x' * 65_536, "\u{1f600}"].each do |content|
        mail = fixture_message('blocklist')
        rewrite_body(mail) { |text| "#{text}\n#{content}\n" }
        expect(handle(mail, dry_run: false).incidents).to be_empty
        expect(IncidentReport.records).to be_empty
      end
    end

    it 'bounds report sections, JSON and decoded evidence and rejects invalid UTF-8' do
      mail = fixture_message('blocklist')
      rewrite_report(mail) { 'x' * (AbuseNoticeParser::Utils::MAX_NOTICE_BYTES + 1) }
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('lrob')
      rewrite_json(mail) { |data| data.fetch('evidence').first['payload'] = ["\xff".b].pack('m0') }
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('lrob')
      rewrite_json(mail) { |data| data['description'] = 'x' * (AbuseNoticeParser::Utils::MAX_NOTICE_BYTES + 1) }
      expect(handle(mail).incidents).to be_empty
      mail = fixture_message('lrob')
      rewrite_json(mail) { |data| data.fetch('evidence').first['payload'] = ['x' * (AbuseNoticeParser::XArfDecoder::MAX_EVIDENCE_BYTES + 1)].pack('m0') }
      expect(handle(mail).incidents).to be_empty
    end

    it 'requires nonempty readable content even when LRob JSON metadata is valid' do
      mail = fixture_message('lrob')
      rewrite_body(mail) { '' }
      rewrite_json(mail) { |data| data['evidence'] = [] }
      expect(handle(mail).incidents).to be_empty
    end
  end
end
