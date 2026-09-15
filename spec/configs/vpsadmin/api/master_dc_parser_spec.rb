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

  it 'parses a MasterDC prose UCEPROTECT monitoring report without CSV data' do
    incidents = parse_fixture(described_class, 'masterdc_uceprotect_plain', assignments: ['192.168.65.61'])

    expect(incidents.size).to eq(1)
    incident = incidents.first
    expect(incident.subject).to eq(
      '[MasterDC support #805648] UCEPROTECT Monitoring Report: IP 192.168.65.61'
    )
    expect(incident.detected_at).to eq(Time.new(2026, 4, 20, 8, 56, 47, '+02:00'))
    expect(incident.text).to include('z Vaší IP adresy 192.168.65.61')
    expect(incident.text).to include('honeypotů blacklistu UCEPROTECT')
  end

  describe 'multiple UCEPROTECT entries' do
    let(:first_ip) { '192.0.2.10' }
    let(:second_ip) { '192.0.2.20' }
    let(:csv_header) { 'IP,LAST IMPACT TIMESTAMP,LAST IMPACT GermanTime,earliest expiretime GermanTime' }

    def notice_message(body, subject: nil)
      mail = fixture_message('masterdc_uceprotect_multiple')
      mail.content_transfer_encoding = '8bit'
      mail.body = "Ticket <URL: https://rt.vpsfree.cz/rt/Ticket/Display.html?id=10105 >\n\n#{body}"
      mail.subject = subject if subject
      mail
    end

    def parse_notice(mail, dry_run: true)
      described_class.new(mailbox, mail, dry_run: dry_run).parse
    end

    before do
      register_assignment(first_ip, user_id: 1001, vps_id: 2001)
      register_assignment(second_ip, user_id: 1002, vps_id: 2002)
    end

    it 'decodes a quoted-printable RT notice and saves one incident for each owner' do
      mail = fixture_message('masterdc_uceprotect_multiple')
      incidents = parse_notice(mail, dry_run: false)

      expect(incidents.map { |inc| [inc.user_id, inc.vps_id] }).to eq([[1001, 2001], [1002, 2002]])
      expect(incidents.map(&:detected_at)).to eq([mail.date.to_time, mail.date.to_time])
      expect(IncidentReport.records).to eq(incidents)
      expect(incidents).to all(have_attributes(saved: true))
      incidents.each_with_index do |incident, index|
        ip, other = [first_ip, second_ip].rotate(index)
        expect(incident.subject).to eq("MasterDC UCEPROTECT Monitoring Report: IP #{ip}")
        expect(incident.text).to include(ip, 'MasterDC', 'UCEPROTECT')
        expect(incident.subject + incident.text).not_to include(other)
      end
    end

    it 'returns the same proposed entries without writes in a dry run' do
      incidents = parse_notice(fixture_message('masterdc_uceprotect_multiple'))

      expect(incidents.map(&:user_id)).to eq([1001, 1002])
      expect(IncidentReport.records).to be_empty
      expect(incidents).to all(have_attributes(saved: false))
    end

    it 'keeps separate IP incidents for the same user and VPS' do
      register_assignment(second_ip, user_id: 1001, vps_id: 2001)

      incidents = parse_notice(fixture_message('masterdc_uceprotect_multiple'))

      expect(incidents.size).to eq(2)
      expect(incidents.map(&:user_id)).to eq([1001, 1001])
      expect(incidents.map { |inc| inc.ip_address_assignment.ip_addr }).to eq([first_ip, second_ip])
    end

    it 'reads every CSV row and table even when the subject names one IP' do
      mail = notice_message(<<~TEXT, subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report (#{first_ip})")
        #{csv_header}
        0.0.0.0,,01.01.1970 01:00,08.01.1970 02:00
        #{first_ip},1726798443,20.09.2024 04:14,27.09.2024 05:00
        #{second_ip},1726798500,OTHER USER EVIDENCE,OTHER USER EXPIRY

        #{csv_header}
        #{first_ip},1726798600,,
      TEXT

      incidents = parse_notice(mail)

      expect(incidents.map { |inc| inc.ip_address_assignment.ip_addr }).to eq([first_ip, second_ip, first_ip])
      expect(incidents.map(&:detected_at)).to eq([1_726_798_443, 1_726_798_500, 1_726_798_600].map { |n| Time.at(n) })
      expect(AbuseNoticeParserSpec::AssignmentRegistry.lookups).to eq([
                                                                        { addr_str: first_ip, time: Time.at(1_726_798_443) },
                                                                        { addr_str: second_ip, time: Time.at(1_726_798_500) },
                                                                        { addr_str: first_ip, time: Time.at(1_726_798_600) }
                                                                      ])
      expect(incidents.first.text).to include("#{first_ip},1726798443")
      expect(incidents.first.text).not_to include(second_ip, 'OTHER USER', '1726798600')
      expect(incidents[1].subject).not_to include(first_ip)
    end

    it 'deduplicates CSV rows and uses CSV time instead of overlapping prose time' do
      mail = notice_message(<<~TEXT)
        z Vaší IP adresy #{first_ip}, #{second_ip} pravděpodobně probíhá spamming.

        #{csv_header}
        #{first_ip},1726798443,,
        #{first_ip},1726798443,,
        #{second_ip},1726798500,,
      TEXT

      incidents = parse_notice(mail)

      expect(incidents.map(&:detected_at)).to eq([Time.at(1_726_798_443), Time.at(1_726_798_500)])
    end

    it 'deduplicates repeated prose blocks and canonical IPv6 addresses' do
      register_assignment('2001:db8::1', user_id: 1003, vps_id: 2003)
      mail = notice_message(<<~TEXT)
        z Vaší IP adresy #{first_ip};
        #{second_ip} a 2001:0DB8:0:0:0:0:0:1 pravděpodobně probíhá spamming.

        Your IP addresses #{first_ip}, and 2001:db8::1.
      TEXT

      incidents = parse_notice(mail)

      expect(incidents.map { |inc| inc.ip_address_assignment.ip_addr }).to eq([first_ip, second_ip, '2001:db8::1'])
    end

    it 'accepts a line break before the first address and a plural Czech source label' do
      mail = notice_message("z Vašich IP adres\n#{first_ip} a #{second_ip} pravděpodobně probíhá spamming.")

      expect(parse_notice(mail).map(&:user_id)).to eq([1001, 1002])
    end

    it 'does not collect unrelated header, URL, signature, or receiver addresses' do
      mail = notice_message(<<~TEXT)
        Received: from #{second_ip}
        Receiver IP address #{second_ip}
        https://example.test/#{second_ip}
        z Vaší IP adresy #{first_ip} pravděpodobně probíhá spamming.

        --
        IP address #{second_ip}
      TEXT

      incidents = parse_notice(mail)

      expect(incidents.map { |inc| inc.ip_address_assignment.ip_addr }).to eq([first_ip])
    end

    it 'skips invalid addresses and reports partial success with the RT reference' do
      mail = notice_message("z Vaší IP adresy #{first_ip}, 999.1.2.3, #{second_ip} pravděpodobně probíhá spamming.")
      incidents = nil

      expect { incidents = parse_notice(mail, dry_run: false) }.to output(
        /rt.vpsfree.cz #10105.*notice line 1: invalid IP.*999.1.2.3.*created=2 duplicate=0 sentinel=0 rejected=1/m
      ).to_stderr
      expect(incidents.size).to eq(2)
      expect(incidents.first.text).not_to include(second_ip, '999.1.2.3')
    end

    it 'skips an unassigned IP and does not expose it to the remaining user' do
      mail = notice_message("z Vaší IP adresy #{first_ip}, 192.0.2.30 pravděpodobně probíhá spamming.")
      incidents = nil

      expect { incidents = parse_notice(mail) }.to output(/192.0.2.30 has no assignment.*created=1.*rejected=1/m).to_stderr
      expect(incidents.size).to eq(1)
      expect(incidents.first.text).not_to include('192.0.2.30')
    end

    it 'does not replace an invalid CSV timestamp with the prose date' do
      mail = notice_message(<<~TEXT)
        z Vaší IP adresy #{first_ip}, #{second_ip} pravděpodobně probíhá spamming.

        #{csv_header}
        #{first_ip},not-a-timestamp,,
        #{second_ip},1726798500,,
      TEXT
      incidents = nil

      expect { incidents = parse_notice(mail) }.to output(/row 1: IP #{first_ip} has invalid timestamp/).to_stderr
      expect(incidents.map(&:user_id)).to eq([1002])
      expect(incidents.first.text).not_to include(first_ip)
    end

    it 'uses the message date for an empty CSV timestamp' do
      mail = notice_message("#{csv_header}\n#{first_ip},,,\n")

      expect(parse_notice(mail).first.detected_at).to eq(mail.date.to_time)
    end

    it 'rejects missing message dates without dropping independently timestamped rows' do
      mail = notice_message("#{csv_header}\n#{first_ip},,,\n#{second_ip},1726798500,,\n")
      mail.date = nil

      expect(parse_notice(mail).map(&:user_id)).to eq([1002])
    end

    it 'rejects unrepresentable timestamps without failing other rows' do
      mail = notice_message("#{csv_header}\n#{first_ip},999999999999999999999999,,\n#{second_ip},1726798500,,\n")

      expect(parse_notice(mail).map(&:user_id)).to eq([1002])
    end

    it 'rejects an entire malformed table and still processes the next table' do
      mail = notice_message(<<~TEXT)
        z Vaší IP adresy #{first_ip} pravděpodobně probíhá spamming.

        #{csv_header}
        #{first_ip},1726798443,,
        "unclosed

        #{csv_header}
        #{second_ip},1726798500,,
      TEXT
      incidents = nil

      expect { incidents = parse_notice(mail) }.to output(/invalid CSV/).to_stderr
      expect(incidents.map(&:user_id)).to eq([1002])
      expect(incidents.first.text).not_to include(first_ip)
    end

    it 'does not fall back to the subject after rejecting body entries' do
      mail = notice_message("#{csv_header}\n#{first_ip},bad,,\n",
                            subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report (#{first_ip})")

      expect(parse_notice(mail)).to be_empty
    end

    it 'does not silently select one IP from an unsupported subject-only address list' do
      mail = notice_message('UCEPROTECT reported suspected spamming.',
                            subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report (#{first_ip}, #{second_ip})")

      expect(parse_notice(mail)).to be_empty
    end

    it 'isolates body evidence when a padded subject address list cannot be parsed' do
      mail = notice_message("Your IP address #{first_ip} caused spam.",
                            subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report ( #{first_ip}, #{second_ip} )")
      # Exercise the actual encoded header as received by the mailbox parser.
      mail = Mail.read_from_string(mail.to_s)
      incidents = nil

      expect { incidents = parse_notice(mail) }.to output(/subject: expected one source IP/).to_stderr
      expect(incidents.map(&:user_id)).to eq([1001])
      expect(incidents.first.subject + incidents.first.text).not_to include(second_ip)
    end

    it 'does not retain an unknown subject suffix containing another IP' do
      mail = notice_message("Your IP address #{first_ip} caused spam.",
                            subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report - extra details for #{second_ip}")

      incident = parse_notice(mail).first

      expect(incident.subject + incident.text).not_to include(second_ip)
    end

    it 'accepts whitespace around a single parenthesized subject IP' do
      mail = notice_message('UCEPROTECT reported suspected spamming.',
                            subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report ( #{first_ip} )")

      expect(parse_notice(mail).map(&:user_id)).to eq([1001])
    end

    it 'uses a subject IP when the body contains no recognized entries' do
      mail = notice_message('UCEPROTECT reported suspected spamming.',
                            subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report: IP #{first_ip}")

      expect(parse_notice(mail).map(&:user_id)).to eq([1001])
    end

    it 'logs a conflicting subject but processes the valid body without exposing the subject IP' do
      mail = notice_message("z Vaší IP adresy #{second_ip} pravděpodobně probíhá spamming.",
                            subject: "[rt.vpsfree.cz #10105] UCEPROTECT Monitoring Report (#{first_ip})")
      incidents = nil

      expect { incidents = parse_notice(mail) }.to output(/subject IP #{first_ip} contradicts body entries/).to_stderr
      expect(incidents.map(&:user_id)).to eq([1002])
      expect(incidents.first.subject + incidents.first.text).not_to include(first_ip)
    end

    it 'reports all-invalid input without saving anything' do
      mail = notice_message('z Vaší IP adresy 999.1.2.3, 192.0.2.10/24 pravděpodobně probíhá spamming.')

      expect(parse_notice(mail, dry_run: false)).to be_empty
      expect(IncidentReport.records).to be_empty
    end

    it 'prefers CSV evidence in a separate MIME section over a prose mention' do
      mail = notice_message("z Vaší IP adresy #{first_ip}, #{second_ip} pravděpodobně probíhá spamming.")
      body = mail.body.decoded
      mail.body = nil
      mail.content_type = 'multipart/mixed'
      mail.add_part(Mail::Part.new(body: body, content_type: 'text/plain; charset=UTF-8'))
      mail.add_part(Mail::Part.new(body: "#{csv_header}\n#{first_ip},1726798443,,\n",
                                   content_type: 'text/plain; charset=UTF-8',
                                   content_disposition: 'attachment'))

      incidents = parse_notice(mail)

      expect(incidents.map { |inc| [inc.user_id, inc.detected_at] }).to contain_exactly(
        [1001, Time.at(1_726_798_443)], [1002, mail.date.to_time]
      )
    end

    it 'rejects wrong column counts without reinterpreting the same IP from prose' do
      mail = notice_message(<<~TEXT)
        z Vaší IP adresy #{first_ip}, #{second_ip} pravděpodobně probíhá spamming.

        #{csv_header}
        #{first_ip},1726798443,,,extra
        #{second_ip},1726798500,,
      TEXT

      expect(parse_notice(mail).map(&:user_id)).to eq([1002])
    end

    it 'rejects duplicate CSV columns without falling back to prose' do
      mail = notice_message(<<~TEXT)
        z Vaší IP adresy #{first_ip} pravděpodobně probíhá spamming.

        IP,LAST IMPACT TIMESTAMP,IP
        #{first_ip},1726798443,#{second_ip}
      TEXT

      expect(parse_notice(mail)).to be_empty
    end

    it 'propagates persistence failures instead of treating them as rejected input' do
      incident = instance_double(IncidentReport)
      allow(IncidentReport).to receive(:new).and_return(incident)
      allow(incident).to receive(:save!).and_raise(RuntimeError, 'database unavailable')

      expect { parse_notice(fixture_message('masterdc_uceprotect_multiple'), dry_run: false) }.to raise_error(
        RuntimeError, 'database unavailable'
      )
    end
  end
end
