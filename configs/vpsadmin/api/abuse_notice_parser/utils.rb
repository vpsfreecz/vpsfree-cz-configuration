require 'date'

module AbuseNoticeParser
  module Utils
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

    def message_text_sections
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
                    || content_type.start_with?('message/feedback-report')

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
