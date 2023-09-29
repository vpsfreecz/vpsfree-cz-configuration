module AbuseNoticeParser
  module Utils
    def strip_rt_prefix(subject)
      closing_bracket = subject.index(']')
      return subject if closing_bracket.nil?

      ret = subject[(closing_bracket+1)..-1].strip
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
  end
end
