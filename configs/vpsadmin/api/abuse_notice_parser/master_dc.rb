require 'csv'
require 'date'

module AbuseNoticeParser
  class MasterDc < VpsAdmin::API::IncidentReports::Parser
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
      text = incident_text
      csv_text = uceprotect_csv(text)
      addr_str = nil
      time = nil

      if csv_text
        addr_str, time = parse_uceprotect_csv(csv_text)
      else
        addr_str = uceprotect_notice_ip(text)
        time = message_date

        if addr_str.nil?
          warn 'MasterDC UCEPROTECT: IP not found'
          return []
        end

        if time.nil?
          warn 'MasterDC UCEPROTECT: message date not found'
          return []
        end
      end

      return [] if addr_str.nil? || time.nil?

      create_incident(addr_str, text, time, label: 'MasterDC UCEPROTECT')
    end

    def parse_uceprotect_csv(csv_text)
      begin
        csv = CSV.parse(csv_text, headers: true)
      rescue CSV::MalformedCSVError => e
        warn "MasterDC UCEPROTECT: invalid csv: #{e.message}"
        return [nil, nil]
      end

      subject_ip = uceprotect_subject_ip
      row = csv.find do |entry|
        ip = entry['IP'].to_s.strip
        next false if ip.empty? || ip == '0.0.0.0'

        subject_ip.nil? || ip == subject_ip
      end

      if row.nil?
        warn 'MasterDC UCEPROTECT: no matching IP found in csv'
        return [nil, nil]
      end

      addr_str = row['IP'].to_s.strip
      timestamp = row['LAST IMPACT TIMESTAMP'].to_s.strip

      if timestamp.empty?
        time = message_date

        if time.nil?
          warn 'MasterDC UCEPROTECT: message date not found'
          return [nil, nil]
        end
      else
        begin
          time = Time.at(Integer(timestamp))
        rescue ArgumentError, TypeError => e
          warn "MasterDC UCEPROTECT: invalid timestamp #{timestamp.inspect}: #{e.message}"
          return [nil, nil]
        end
      end

      [addr_str, time]
    end

    def uceprotect_csv(text)
      lines = []
      capture = false

      text.each_line do |line|
        capture = true if line.start_with?('IP,LAST IMPACT TIMESTAMP,')
        next unless capture

        break if line.strip.empty? && lines.any?

        lines << line
      end

      csv_text = lines.join.strip
      csv_text.empty? ? nil : csv_text
    end

    def uceprotect_subject_ip
      subject = strip_rt_prefix(message.subject)
      pattern = %r{UCEPROTECT Monitoring Report(?: \(| - |: IP )([0-9a-f:.]+)}i
      return ::Regexp.last_match(1) if pattern =~ subject

      nil
    end

    def uceprotect_notice_ip(text)
      subject_ip = uceprotect_subject_ip
      return subject_ip if subject_ip

      text.each_line do |line|
        next unless /(?:IP address|IP adres[ay]|IP)\s+([0-9a-f:.]+)/i =~ line

        return ::Regexp.last_match(1).sub(/[.,;]+\z/, '')
      end

      nil
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
      [incident]
    end
  end
end
