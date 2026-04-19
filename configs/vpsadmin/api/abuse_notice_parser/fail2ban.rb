require 'date'

module AbuseNoticeParser
  class Fail2Ban < VpsAdmin::API::IncidentReports::Parser
    def self.match_subject?(subject)
      subject.start_with?('Automatic abuse report for IP address ') \
        || subject.match?(/\AAbuse from \S+\z/)
    end

    def self.match_sender?(from)
      from.start_with?('fail2ban@')
    end

    def self.match_message?(subject, from, check_sender: true)
      return false unless match_subject?(subject)

      if subject.start_with?('Automatic abuse report for IP address ')
        !check_sender || match_sender?(from)
      else
        true
      end
    end

    include Utils

    def parse
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
    end

    protected

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
