require 'date'

module AbuseNoticeParser
  class XArf < VpsAdmin::API::IncidentReports::Parser
    PROFILE_ORIGINATORS = {
      blocklist: 'abuse-team@blocklist.de',
      cedo: 'www-root@cedo.com',
      provider_tools: 'noreply@provider.tools'
    }.freeze

    def self.match_subject?(subject)
      subject.match?(/\Aabuse report about [^ ]+ - \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}\z/)
    end

    def self.match_sender?(_from)
      true
    end

    def self.profile(subject, from: nil)
      if subject.start_with?('[noreply] abuse report about ')
        :blocklist
      elsif (from == PROFILE_ORIGINATORS.fetch(:cedo) && subject.start_with?('abuse report about ')) \
            || subject.match?(/\Aabuse report about \S+ - (?:[A-Z][a-z]{2}, )?\d{1,2} [A-Z][a-z]{2} /)
        :cedo
      elsif subject.start_with?('[X-ARF] Abuse report: ')
        :provider_tools
      end
    end

    def self.match_message?(subject, from, message:, check_sender: true)
      selected = profile(subject, from: from)
      return match_subject?(subject) if selected.nil?

      !check_sender || from == PROFILE_ORIGINATORS.fetch(selected)
    end

    include Utils

    def processed?
      @processed.nil? ? true : @processed
    end

    def parse
      selected = self.class.profile(strip_rt_prefix(message.subject), from: message['X-RT-Originator'].to_s)
      return parse_profile(selected) unless selected.nil?

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

    protected

    def parse_profile(profile)
      @processed = false
      if sender_check_enabled? && message['X-RT-Originator'].to_s != PROFILE_ORIGINATORS.fetch(profile)
        notice_error('unexpected RT originator')
      end
      profile == :provider_tools ? parse_provider_tools : parse_structured_text(profile)
    rescue NoticeError => e
      notice_warning('XARF text', e.message)
      []
    end

    def parse_structured_text(profile)
      parts = message.parts.select { |part| part.filename.to_s.casecmp?('report.txt') }
      notice_error('expected one top-level text/plain report.txt') unless parts.length == 1 && parts.first.mime_type == 'text/plain'
      fields = notice_fields(
        bounded_notice_text(parts.first.decoded.to_s),
        keys: %w[Version Source-Type Category Report-Type Reported-From Source Date]
      )
      unless required_notice_field(fields, 'Version') == '0.2' \
             && required_notice_field(fields, 'Source-Type') == 'ip-address' \
             && required_notice_field(fields, 'Category') == 'abuse' \
             && required_notice_field(fields, 'Report-Type') == 'login-attack'
        notice_error('unsupported structured report profile')
      end
      expected = PROFILE_ORIGINATORS.fetch(profile)
      if sender_check_enabled? && (message['X-RT-Originator'].to_s != expected || fields['Reported-From'] != expected)
        notice_error('RT originator and structured reporter do not match')
      end
      source = notice_ip(required_notice_field(fields, 'Source'))
      time = notice_time(required_notice_field(fields, 'Date'))
      corroborate_notice_subject(source, /\A(?:\[noreply\] )?abuse report about (\S+) - /)
      incidents = notice_incident(source, time, notice_text)
      @processed = true
      incidents
    end

    def parse_provider_tools
      body = notice_body
      unless body.scan(/^X-XARF:/).length == 1 && body.scan(/^X-XARF: PLAIN\s*$/).length == 1 \
             && body.scan(/^Summary \(anonymized\):/).length == 1
        notice_error('expected one inline X-XARF block and summary')
      end
      match = /^X-XARF: PLAIN\s*\n(.*?)\n\s*Summary \(anonymized\):\s*\n(.*?)(?:\n\s*\n|\z)/m.match(body)
      notice_error('missing inline fields or summary') if match.nil?
      fields = notice_fields(match[1], keys: %w[Source-Type Abuse-Category Report-Type Source])
      summary = notice_fields(match[2], keys: ['IP', 'Last seen'])
      unless required_notice_field(fields, 'Source-Type') == 'ip-address' \
             && required_notice_field(fields, 'Abuse-Category') == 'abuse' \
             && required_notice_field(fields, 'Report-Type') == 'Abuse/Policy'
        notice_error('unsupported inline profile')
      end
      source = notice_ip(required_notice_field(fields, 'Source'))
      corroborate_notice_source(source, [required_notice_field(summary, 'IP')])
      corroborate_notice_subject(source, %r{\A\[X-ARF\] Abuse report: (\S+) \(Abuse/Policy\)\z})
      last = notice_time(required_notice_field(summary, 'Last seen'))
      incidents = notice_incident(source, last, notice_text)
      @processed = true
      incidents
    end
  end
end
