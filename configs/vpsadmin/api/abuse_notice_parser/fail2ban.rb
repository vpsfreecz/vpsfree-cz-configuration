require 'date'

module AbuseNoticeParser
  class Fail2Ban < VpsAdmin::API::IncidentReports::Parser
    REPORT_LOG_SECTION = /^Lines containing failures of [^\n]+\n(.*?)(?:\n[ \t]*\n|\z)/m

    def self.match_subject?(subject)
      subject.start_with?('Automatic abuse report for IP address ') \
        || subject.match?(/\AAbuse from \S+\z/)
    end

    def self.match_sender?(from)
      from.start_with?('fail2ban@')
    end

    def self.match_message?(subject, from, message: nil, check_sender: true)
      return false unless match_subject?(subject)

      if subject.start_with?('Automatic abuse report for IP address ')
        !check_sender || match_sender?(from)
      else
        true
      end
    end

    include Utils

    def parse
      if strip_rt_prefix(message.subject).start_with?('Abuse from ')
        body = notice_body
        sections = body.scan(REPORT_LOG_SECTION).flatten
        return parse_syslog_notice(body) if sections.any? { |section| section.match?(/^[A-Z][a-z]{2}\s+\d{1,2} /) }
      end
      body = message.decoded

      if /^This is an email abuse report about the IP address (.+) generated at ([^$]+?)$/ =~ body
        addr_str = ::Regexp.last_match(1)
        time_str = ::Regexp.last_match(2)

        begin
          # Fri Sep 15 18:55:37 EEST 2023
          time = DateTime.strptime(time_str, '%a %b %d %H:%M:%S %Z %Y').to_time
        rescue Date::Error => e
          warn "Fail2Ban: invalid timestamp #{time_str.inspect}: #{e.message}"
          return []
        end
      elsif /We have detected abuse .* from the IP address ([^,\s]+),/ =~ body
        addr_str = ::Regexp.last_match(1)
        time = parse_access_log_time(body)

        if time.nil?
          warn 'Fail2Ban: detected time not found'
          return []
        end
      elsif /Abuse from ([^ ]+)/ =~ message.subject
        addr_str = ::Regexp.last_match(1)
        time = parse_access_log_time(body, fallback: false)

        if time.nil?
          warn 'Fail2Ban: detected time not found'
          return []
        end
      else
        warn 'Fail2Ban: IP / date not found'
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "Fail2Ban: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if text.empty?
        warn 'Fail2Ban: empty message body'
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
    rescue NoticeError => e
      notice_warning('Fail2Ban', e.message)
      []
    end

    protected

    def parse_syslog_notice(body)
      subject = /\AAbuse from (\S+)\z/.match(strip_rt_prefix(message.subject))
      notice_error('missing source in provider subject') if subject.nil?
      source = notice_ip(subject[1])
      notice_incident(source, parse_syslog_time(body), notice_text)
    end

    def parse_syslog_time(body)
      offsets = body.scan(/^Note: Local timezone is ([+-]\d{4})(?:\s|$)/).flatten
      notice_error('missing or competing numeric log timezone') unless offsets.length == 1
      reference = notice_time(message[:date]&.value.to_s.strip)
      offset = offsets.first
      local_reference = reference.getlocal(offset)
      sections = body.scan(REPORT_LOG_SECTION).flatten
      notice_error('expected one report log section') unless sections.length == 1
      times = sections.first.lines.filter_map do |line|
        next unless line.match?(/\A[A-Z][a-z]{2}\s+\d{1,2} /)

        match = /\A([A-Z][a-z]{2})\s+(\d{1,2}) (\d{2}:\d{2}:\d{2})(?:\s|\z)/.match(line.chomp)
        notice_error('invalid syslog timestamp prefix') if match.nil?
        candidates = ((local_reference.year - 1)..(local_reference.year + 1)).filter_map do |year|
          candidate = notice_time("#{match[2]} #{match[1]} #{year} #{match[3]} #{offset}")
          candidate if candidate <= reference && reference - candidate <= 31 * 86_400
        rescue NoticeError
          nil
        end
        notice_error('syslog date has no unique past year within 31 days') unless candidates.length == 1
        candidates.first
      end
      notice_error('no report log timestamp prefixes') if times.empty?
      times.max
    rescue ArgumentError
      notice_error('invalid numeric log timezone')
    end

    def parse_access_log_time(body, fallback: true)
      times = body.scan(
        %r{\[(\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2} [+-]\d{4})\]}
      ).filter_map do |match|
        time_str = Array(match).first

        begin
          DateTime.strptime(time_str, '%d/%b/%Y:%H:%M:%S %z').to_time
        rescue Date::Error
          nil
        end
      end

      return times.max unless times.empty?

      fallback ? message_date : nil
    end
  end
end
