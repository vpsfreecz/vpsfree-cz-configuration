require 'date'

module AbuseNoticeParser
  class Fail2Ban < VpsAdmin::API::IncidentReports::Parser
    def self.match_subject?(subject)
      subject.start_with?('Automatic abuse report for IP address ')
    end

    def self.match_sender?(from)
      from.start_with?('fail2ban@')
    end

    include Utils

    def parse
      body = message.decoded

      if /^This is an email abuse report about the IP address (.+) generated at ([^$]+?)$/ !~ body
        warn 'Fail2Ban: IP / date not found'
        return []
      end

      addr_str = ::Regexp.last_match(1)
      time_str = ::Regexp.last_match(2)

      begin
        # Fri Sep 15 18:55:37 EEST 2023
        time = DateTime.strptime(time_str, '%a %b %d %H:%M:%S %Z %Y').to_time
      rescue Date::Error => e
        warn "Fail2Ban: invalid timestamp #{time_str.inspect}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "Fail2Ban: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)
      text = strip_rt_header(body)

      if body.empty?
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
  end
end
