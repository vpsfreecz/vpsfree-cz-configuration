require 'date'

module AbuseNoticeParser
  class LeakIX < VpsAdmin::API::IncidentReports::Parser
    def self.match_subject?(subject)
      subject.start_with?('[LeakIX] Critical security issue for ')
    end

    def self.match_sender?(from)
      from == 'apiguardian@leakix.net'
    end

    include Utils

    def parse
      if /Critical security issue for ([^$]+)$/ !~ message.subject
        warn 'LeakIX: source IP not found'
        return []
      end

      addr_str = ::Regexp.last_match(1)

      body = message.decoded

      if /\|\s+Discovered\s+\|\s+(\d+ \w+ \d+ \d+:\d+ UTC)/ !~ body
        warn 'LeakIX: timestamp not found'
        return []
      end

      time_str = ::Regexp.last_match(1)

      begin
        time = DateTime.strptime("#{time_str} UTC", '%d %b %y %H:%M %Z').to_time
      rescue Date::Error => e
        warn "LeakIX: invalid timestamp #{::Regexp.last_match(1).inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "LeakIX: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
        warn 'LeakIX: empty message body'
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
