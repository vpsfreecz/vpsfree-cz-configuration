require 'date'

module AbuseNoticeParser
  class BitNinja < VpsAdmin::API::IncidentReports::Parser
    def self.match_subject?(subject)
      /^Your server [^ ]+ has been registered as an attack source$/ =~ subject
    end

    def self.match_sender?(from)
      from == 'info@bitninja.com'
    end

    include Utils

    def parse
      if /Your server ([^ ]+) has been/ !~ message.subject
        warn "BitNinja: source IP not found"
        return []
      end

      addr_str = $1

      body = message.decoded

      # . is instead of nonbreaking space...
      if /Timestamp \(UTC\):.(\d+\-\d+\-\d+ \d+:\d+:\d+)/ !~ body
        warn "BitNinja: timestamp not found"
        return []
      end

      time_str = $1

      begin
        time = DateTime.strptime("#{time_str} UTC", '%Y-%m-%d %H:%M:%S %Z').to_time
      rescue Date::Error => e
        warn "BitNinja: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "BitNinja: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
        warn "BitNinja: empty message body"
        return []
      end

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: time,
      )

      incident.save! unless dry_run?
      [incident]
    end
  end
end
