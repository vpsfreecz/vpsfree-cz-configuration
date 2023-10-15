require 'date'

module AbuseNoticeParser
  class SpamCop < VpsAdmin::API::IncidentReports::Parser
    def self.match_subject?(subject)
      subject.start_with?('[SpamCop (')
    end

    def self.match_sender?(from)
      from.end_with?('@reports.spamcop.net')
    end

    include Utils

    def parse
      body = message.decoded

      if /^Email from ([^\s]+) \/ ([^$]+?)$/ !~ body
        warn "SpamCop: IP / date not found"
        return []
      end

      addr_str = $1
      time_str = $2

      begin
        time = DateTime.rfc2822(time_str).to_time
      rescue Date::Error => e
        warn "SpamCop: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "SpamCop: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
        warn "SpamCop: empty message body"
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
