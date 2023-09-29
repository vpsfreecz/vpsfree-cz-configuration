require 'date'

module AbuseNoticeParser
  class UsGo < VpsAdmin::API::IncidentReports::Parser
    def self.match_subject?(subject)
      subject.start_with?('Abuse Feedback Report for ')
    end

    def self.match_sender?(from)
      from == 'DoNotReply@USGOabuse.net'
    end

    include Utils

    def parse
      if !message.multipart? || message.parts.length < 3
        warn "USGO: expected a 3-part message, got #{message.parts.length} parts"
        return []
      end

      feedback = message.parts[1].decoded

      if /^Source-IP: ([^$]+?)$/ !~ feedback
        warn "USGO: IP not found"
        return []
      end

      addr_str = $1

      if /^Received-Date: ([^\(]+)/ !~ feedback
        warn "USGO: datetime not found"
        return []
      end

      time_str = $1

      begin
        time = DateTime.rfc2822(time_str).to_time
      rescue Date::Error => e
        warn "USGO: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "USGO: IP #{addr_str} not found"
        return []
      end

      body = message.parts[0].decoded

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      spam_body = message.parts[2].decoded
      text << "\n\nOffending message:\n\n#{spam_body}"

      if body.empty?
        warn "USGO: empty message body"
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
