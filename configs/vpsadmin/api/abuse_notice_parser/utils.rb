require 'date'
require 'ipaddr'
require 'time'

module AbuseNoticeParser
  module Utils
    class NoticeError < StandardError; end

    MAX_NOTICE_BYTES = 1024 * 1024

    def notice_error(reason)
      raise NoticeError, reason
    end

    def notice_warning(provider, reason)
      reference = message.subject.to_s[/\[rt\.vpsfree\.cz #\d+\]/] || 'RT notice'
      warn "#{provider}: #{reference}: #{reason}"
    end

    def sender_check_enabled?
      !ENV.has_key?('CHECK_SENDER') || %w[y yes 1].include?(ENV.fetch('CHECK_SENDER'))
    end

    # Only the observed top-level plain section belongs to these profiles.
    # Never descend into forwarded messages or flatten attachments into prose.
    def notice_body
      if message.multipart?
        primary_parts = message.parts.select do |candidate|
          candidate.mime_type == 'text/plain' && candidate.filename.nil? \
            && !candidate.content_disposition.to_s.downcase.start_with?('attachment')
        end
        notice_error('expected one primary text/plain section') unless primary_parts.length == 1
      end
      part = message.multipart? ? primary_text_part : message
      notice_error('missing primary text/plain section') if part.nil? || part.mime_type != 'text/plain'

      bounded_notice_text(strip_rt_header(part.decoded.to_s))
    end

    def notice_text(evidence: [])
      notice_body
      sections = message_text_sections(plain_only: true).map { |section| bounded_notice_text(section) }
      append_text_sections('', sections + evidence)
    end

    def bounded_notice_text(text)
      notice_error('report section is too large') if text.bytesize > MAX_NOTICE_BYTES
      notice_error('report section is not valid UTF-8') unless text.dup.force_encoding('UTF-8').valid_encoding?

      text.dup.force_encoding('UTF-8').gsub("\r\n", "\n")
    end

    def notice_fields(text, keys:)
      fields = {}
      text.each_line do |line|
        next if line.strip.empty? || line.strip == '---'

        match = /\A\s*([A-Za-z][A-Za-z -]*):\s*(.*?)\s*\z/.match(line.chomp)
        next if match.nil? || !keys.include?(match[1])

        key, value = match.captures
        notice_error("duplicate #{key} field") if fields.has_key?(key)

        fields[key] = value
      end
      fields
    end

    def required_notice_field(fields, key)
      value = fields[key]
      notice_error("missing #{key} field") if value.nil? || value.empty?
      value
    end

    def notice_ip(value)
      notice_error('source is not a host IP address') unless value.is_a?(String) && value == value.strip && !value.include?('/')

      IPAddr.new(value).to_s
    rescue IPAddr::InvalidAddressError
      notice_error('source is not a host IP address')
    end

    def notice_time(value)
      notice_error('event date/time is not a valid string') unless value.is_a?(String) && value.valid_encoding?

      iso = /\A(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d+)?(Z|[+-]\d{2}:?\d{2})\z/.match(value)
      if iso
        year, month, day, hour, minute, second = iso.captures.first(6).map(&:to_i)
        offset = iso[8]
        valid_notice_calendar!(year, month, day, hour, minute, second, offset)
        return Time.iso8601(value.sub(/([+-]\d{2})(\d{2})\z/, '\\1:\\2'))
      end

      rfc = /\A(?:[A-Z][a-z]{2}, )?(\d{1,2}) ([A-Z][a-z]{2}) (\d{4}) (\d{2}):(\d{2}):(\d{2}) ([+-]\d{4})\z/.match(value)
      notice_error('event time requires a complete date and numeric UTC offset') if rfc.nil?
      time = DateTime.rfc2822(value).to_time
      valid_notice_calendar!(time.year, time.month, time.day, rfc[4].to_i, rfc[5].to_i, rfc[6].to_i, rfc[7])
      time
    rescue ArgumentError
      notice_error('invalid event date/time')
    end

    def valid_notice_calendar!(year, month, day, hour, minute, second, offset)
      valid_offset = offset == 'Z' || (offset.delete('+-:')[0, 2].to_i <= 23 && offset.delete('+-:')[2, 2].to_i <= 59)
      return if Date.valid_date?(year, month, day) && hour <= 23 && minute <= 59 && second <= 59 && valid_offset

      notice_error('invalid event date/time')
    end

    def notice_utc_time(value)
      notice_error('event date/time is not a valid string') unless value.is_a?(String) && value.valid_encoding?

      match = /\A(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}) UTC\z/.match(value)
      notice_error('event time requires explicit UTC') if match.nil?
      notice_time("#{match[1]}T#{match[2]}Z")
    end

    def corroborate_notice_source(source, claims)
      notice_error('conflicting source addresses') unless claims.all? { |claim| notice_ip(claim) == source }
    end

    def corroborate_notice_subject(source, pattern)
      match = pattern.match(strip_rt_prefix(message.subject))
      notice_error('missing source in provider subject') if match.nil?
      corroborate_notice_source(source, match.captures)
    end

    def notice_assignment(source, time)
      assignment = find_ip_address_assignment(source, time: time)
      notice_error('source has no assignment at event time') if assignment.nil?
      assignment
    end

    def notice_incident(source, time, text)
      subject = strip_rt_prefix(message.subject)
      unless !text.empty? && subject.length <= 255 && text.bytesize <= 65_535 \
             && [subject, text].all? { |value| value.valid_encoding? && value.codepoints.none? { |c| c > 0xffff } }
        notice_error('incident content exceeds storage limits or uses unsupported characters')
      end
      assignment = notice_assignment(source, time)
      incident = ::IncidentReport.new(
        user_id: assignment.user_id, vps_id: assignment.vps_id,
        ip_address_assignment: assignment, mailbox: mailbox,
        subject: subject, text: text, detected_at: time
      )
      incident.save! unless dry_run?
      [incident]
    end

    def strip_rt_prefix(subject)
      closing_bracket = subject.index(']')
      return subject if closing_bracket.nil?

      ret = subject[(closing_bracket + 1)..].strip
      ret.empty? ? 'No subject' : ret
    end

    def strip_rt_header(body)
      ret = ''
      append = false

      body.each_line do |line|
        if line.lstrip.start_with?('Ticket <URL: ')
          append = true
        elsif append
          ret << line
        end
      end

      ret.strip
    end

    def primary_text_part
      return nil unless message.multipart?

      message.parts.detect do |part|
        content_type = part.content_type.to_s
        disposition = part.content_disposition.to_s.downcase

        content_type.start_with?('text/plain') \
          && part.filename.nil? \
          && !disposition.start_with?('attachment')
      end
    end

    def message_text_sections(plain_only: false)
      unless message.multipart?
        body = strip_rt_header(message.decoded.to_s)
        return body.empty? ? [] : [body]
      end

      primary = primary_text_part
      sections = []
      primary_body = strip_rt_header((primary || message).decoded.to_s)
      sections << primary_body unless primary_body.empty?

      message.parts.each do |part|
        next if primary && part.equal?(primary)

        content_type = part.content_type.to_s
        next unless content_type.start_with?('text/plain') \
                    || (!plain_only && content_type.start_with?('message/feedback-report'))

        body = part.decoded.to_s.strip
        next if body.empty?

        sections << body
      end

      sections
    end

    def append_text_sections(text, sections)
      ret = text.to_s.strip

      sections.each do |section|
        section = section.to_s.strip
        next if section.empty?
        next if !ret.empty? && ret.include?(section)

        ret << "\n\n" unless ret.empty?
        ret << section
      end

      ret
    end

    def incident_text
      append_text_sections('', message_text_sections)
    end

    def message_date
      parsed_date = message.date
      return parsed_date.to_time if parsed_date.respond_to?(:to_time)

      raw_date = message[:date]&.value.to_s.strip
      return nil if raw_date.empty?

      DateTime.rfc2822(raw_date).to_time
    rescue ArgumentError
      nil
    end
  end
end
