require 'csv'
require 'date'
require 'ipaddr'
require 'strscan'

module AbuseNoticeParser
  class MasterDc < VpsAdmin::API::IncidentReports::Parser
    UCEPROTECT_NOTICE = /^(?:[ \t]*(?:z\s+Vaš(?:í|ich)\s+|from\s+(?:your\s+)?|your\s+)?)IP(?:\s+(?:addresses|address|adres[ay]?))?[ \t]*:?\s+/i
    UCEPROTECT_CSV_HEADER = 'IP,LAST IMPACT TIMESTAMP,'.freeze

    def self.match_subject?(subject)
      subject.match?(/Abuse report #[^ ]+ from /) \
        || subject.include?('SBL Notify: IP:') \
        || subject.include?('UCEPROTECT Monitoring Report')
    end

    def self.match_sender?(from)
      %w[abuse@master.cz support@master.cz].include?(from)
    end

    include Utils

    def parse
      subject = strip_rt_prefix(message.subject)

      if subject.include?('Abuse report #')
        parse_spfbl
      elsif subject.include?('SBL Notify: IP:')
        parse_sbl
      elsif subject.include?('UCEPROTECT Monitoring Report')
        parse_uceprotect
      else
        warn "MasterDC: unknown subject #{subject.inspect}"
        []
      end
    end

    protected

    def parse_spfbl
      text = incident_text

      unless /^\s*Source-IP:\s*([^\s]+)\s*$/ =~ text \
             || /Abuse report #[^ ]+ from ([^ ]+)/ =~ message.subject
        warn 'MasterDC SPFBL: IP not found'
        return []
      end

      addr_str = ::Regexp.last_match(1)

      if /^\s*Arrival-Date:\s*(.+?)\s*$/ !~ text
        warn 'MasterDC SPFBL: arrival date not found'
        return []
      end

      time_str = ::Regexp.last_match(1)

      begin
        time = DateTime.rfc2822(time_str).to_time
      rescue Date::Error => e
        warn "MasterDC SPFBL: invalid arrival date #{time_str.inspect}: #{e.message}"
        return []
      end

      create_incident(addr_str, text, time, label: 'MasterDC SPFBL')
    end

    def parse_sbl
      text = incident_text

      unless %r{^\s*IP/cidr:\s*([^\s]+)\s*$} =~ text \
             || /SBL Notify: IP: ([^ ]+) added to Spamhaus Block List \(SBL\)/ =~ message.subject
        warn 'MasterDC SBL: IP not found'
        return []
      end

      addr_str = ::Regexp.last_match(1).split('/').first
      time = message_date

      if time.nil?
        warn 'MasterDC SBL: message date not found'
        return []
      end

      create_incident(addr_str, text, time, label: 'MasterDC SBL')
    end

    def parse_uceprotect
      @uceprotect_body_report = false
      @uceprotect_csv_ips = []
      @uceprotect_counts = { created: 0, duplicate: 0, sentinel: 0, rejected: 0 }
      sections = message_text_sections
      entries = sections.each_with_index.flat_map do |section, index|
        uceprotect_entries(section, index + 1)
      end
      entries.reject! do |entry|
        next false if entry[:csv] || !@uceprotect_csv_ips.include?(entry[:ip])

        @uceprotect_counts[:duplicate] += 1
        true
      end
      subject_ip = uceprotect_subject_ip

      if entries.empty? && !@uceprotect_body_report
        if subject_ip
          entries << { ip: subject_ip, timestamp: '', location: 'subject', order: [0, 0] }
        else
          reject_uceprotect('message', 'no source IP found')
        end
      end

      body_ips = entries.map { |entry| entry[:ip] }.compact.uniq
      conflict = subject_ip && body_ips.any? && !body_ips.include?(subject_ip)
      uceprotect_log("subject IP #{subject_ip} contradicts body entries") if conflict

      reports = uceprotect_reports(entries.sort_by { |entry| entry[:order] })
      # Decide before assignment lookup: a rejected or unassigned second entry
      # must not expose the original multi-user message to the first user.
      original = reports.size == 1 && @uceprotect_counts[:rejected] == 0 && !conflict
      text = incident_text

      incidents = reports.filter_map do |report|
        assignment = find_ip_address_assignment(report[:ip], time: report[:time])
        if assignment.nil?
          reject_uceprotect(report[:location], "IP #{report[:ip]} has no assignment")
          next
        end

        subject, body = if original
                          [strip_rt_prefix(message.subject), text]
                        else
                          uceprotect_incident_content(report)
                        end

        if body.empty? || body.bytesize > 65_535 || subject.length > 255
          reject_uceprotect(report[:location], "IP #{report[:ip]} has invalid incident text or subject length")
          next
        end

        incident = create_assigned_incident(assignment, subject: subject, text: body, time: report[:time])
        @uceprotect_counts[:created] += 1
        incident
      end

      uceprotect_log("#{dry_run? ? 'dry run' : 'result'}: " \
                     "#{@uceprotect_counts.map { |key, value| "#{key}=#{value}" }.join(' ')}")
      incidents
    end

    def uceprotect_entries(section, section_number)
      # RT's decoded primary body and attachments are independent sections.
      # A broken table has unknown row boundaries: do not reinterpret prose in
      # that section as a replacement for its possibly timestamped CSV entries.
      tables = []
      prose = []
      table = nil
      section.each_line.with_index(1) do |line, number|
        break if line.match?(/^--\s*$/)

        if line.start_with?(UCEPROTECT_CSV_HEADER)
          @uceprotect_body_report = true
          table = { text: +line, line: number }
          prose << "\n"
          tables << table
        elsif line.strip.empty?
          table = nil
          prose << line
        elsif table
          table[:text] << line
          prose << "\n"
        else
          prose << line
        end
      end

      broken_table = false
      entries = tables.flat_map do |data|
        location = "section #{section_number} CSV line #{data[:line]}"
        begin
          csv = CSV.parse(data[:text])
        rescue CSV::MalformedCSVError => e
          reject_uceprotect(location, "invalid CSV: #{e.message}")
          broken_table = true
          next []
        end

        headers = csv.shift
        if headers.uniq != headers || headers.include?(nil) || csv.empty?
          reject_uceprotect(location, 'empty CSV table or duplicate columns')
          broken_table = true
          next []
        end

        csv.each_with_index.filter_map do |fields, index|
          row = headers.zip(fields).to_h
          row_location = "#{location} row #{index + 1}"
          raw_ip = row['IP'].to_s.strip
          if raw_ip == '0.0.0.0'
            @uceprotect_counts[:sentinel] += 1
            next
          end

          ip = uceprotect_ip(raw_ip, row_location)
          next if ip.nil?

          @uceprotect_csv_ips << ip
          if fields.length != headers.length
            reject_uceprotect(row_location, "IP #{ip} has an invalid CSV column count")
            next
          end

          { ip: ip, timestamp: row['LAST IMPACT TIMESTAMP'].to_s.strip,
            csv: true, location: row_location, order: [section_number, data[:line] + index + 1] }
        end
      end

      return entries if broken_table

      prose_text = prose.join
      prose_text.scan(UCEPROTECT_NOTICE) do
        match = ::Regexp.last_match
        @uceprotect_body_report = true
        line = prose_text[0...match.begin(0)].count("\n") + 1
        location = "section #{section_number} notice line #{line}"
        scanner = StringScanner.new(prose_text[match.end(0)..])
        loop do
          raw_ip = scanner.scan(/[^\s,;]+/).to_s.sub(/[.)]+\z/, '')
          ip = uceprotect_ip(raw_ip, location)
          if ip
            entries << { ip: ip, timestamp: '', location: location,
                         order: [section_number, line] }
          end
          break unless scanner.scan(/\s*(?:[,;]\s*(?:(?:and|a)\s+)?|(?:and|a)\s+)/i)
        end
      end
      entries
    end

    def uceprotect_reports(entries)
      seen = {}
      entries.filter_map do |entry|
        timestamp = entry[:timestamp]
        begin
          time = timestamp.empty? ? message_date : Time.at(Integer(timestamp, 10))
        rescue ArgumentError, TypeError, RangeError => e
          reject_uceprotect(entry[:location], "IP #{entry[:ip]} has invalid timestamp #{timestamp.inspect}: #{e.message}")
          next
        end
        if time.nil? || !time.year.between?(1000, 9999)
          reject_uceprotect(entry[:location], "IP #{entry[:ip]} has missing or out-of-range detection time")
          next
        end

        key = [entry[:ip], time]
        if seen[key]
          @uceprotect_counts[:duplicate] += 1
          next
        end
        seen[key] = true
        entry.merge(time: time)
      end
    end

    def uceprotect_ip(raw_ip, location)
      # IPAddr accepts CIDRs and zone identifiers; reports must name a host.
      if raw_ip.empty? || raw_ip.match?(%r{[/%\[\]]})
        reject_uceprotect(location, "invalid IP #{raw_ip.inspect}")
        return
      end

      IPAddr.new(raw_ip).to_s
    rescue IPAddr::Error => e
      reject_uceprotect(location, "invalid IP #{raw_ip.inspect}: #{e.message}")
      nil
    end

    def uceprotect_subject_ip
      suffix = strip_rt_prefix(message.subject).split(/UCEPROTECT Monitoring Report/i, 2).last.to_s.strip
      return if suffix.empty?

      # Unknown or malformed subject suffixes can contain another user's IP.
      # Only an absent suffix or a validated single IP allows original text.
      match = /\A(?:\(\s*([^()\s,;]+)\s*\)|(?:-\s*|:\s*IP\s+)([^()\s,;]+))\z/i.match(suffix)
      if match.nil?
        reject_uceprotect('subject', 'expected one source IP; use body entries or manual review')
        return
      end

      uceprotect_ip((match[1] || match[2]).sub(/[.;]+\z/, ''), 'subject')
    end

    def uceprotect_incident_content(report)
      subject = "MasterDC UCEPROTECT Monitoring Report: IP #{report[:ip]}"
      text = <<~TEXT
        MasterDC reported this IP address in a UCEPROTECT monitoring notice.

        IP address: #{report[:ip]}
        Detected at: #{report[:time].getutc.strftime('%Y-%m-%d %H:%M:%S UTC')}
      TEXT
      if report[:csv]
        text << "\nCSV report:\n"
        text << CSV.generate_line(['IP', 'LAST IMPACT TIMESTAMP'])
        text << CSV.generate_line([report[:ip], report[:timestamp]])
      end
      [subject, text]
    end

    def reject_uceprotect(location, reason)
      @uceprotect_counts[:rejected] += 1
      uceprotect_log("#{location}: #{reason}")
    end

    def uceprotect_log(text)
      reference = message['X-RT-Ticket'].to_s
      reference = message.subject.to_s[/\[rt\.vpsfree\.cz #\d+\]/] if reference.empty?
      warn "MasterDC UCEPROTECT #{reference.inspect} message=#{message.message_id.inspect}: #{text}"
    end

    def create_incident(addr_str, text, time, label:)
      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "#{label}: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)

      if text.empty?
        warn "#{label}: empty message body"
        return []
      end

      [create_assigned_incident(assignment, subject: subject, text: text, time: time)]
    end

    def create_assigned_incident(assignment, subject:, text:, time:)
      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time
      )

      incident.save! unless dry_run?
      incident
    end
  end
end
