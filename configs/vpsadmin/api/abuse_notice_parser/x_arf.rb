require 'date'

module AbuseNoticeParser
  class XArf < VpsAdmin::API::IncidentReports::Parser
    def self.match_subject?(subject)
      subject.match?(/\Aabuse report about [^ ]+ - \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}\z/)
    end

    def self.match_sender?(_from)
      true
    end

    include Utils

    def parse
      text = incident_text

      unless /^\s*Source:\s*([^\s]+)\s*$/ =~ text \
             || /abuse report about ([^ ]+) -/ =~ message.subject
        warn 'XArf: IP not found'
        return []
      end

      addr_str = ::Regexp.last_match(1)

      if /^\s*Date:\s*([^\s]+)\s*$/ !~ text
        warn 'XArf: date not found'
        return []
      end

      time_str = ::Regexp.last_match(1)

      begin
        time = DateTime.strptime(time_str, '%Y-%m-%dT%H:%M:%S%z').to_time
      rescue Date::Error => e
        warn "XArf: invalid date #{time_str.inspect}: #{e.message}"
        return []
      end

      assignment = find_ip_address_assignment(addr_str, time: time)

      if assignment.nil?
        warn "XArf: IP #{addr_str} not found"
        return []
      end

      subject = strip_rt_prefix(message.subject)

      if text.empty?
        warn 'XArf: empty message body'
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
