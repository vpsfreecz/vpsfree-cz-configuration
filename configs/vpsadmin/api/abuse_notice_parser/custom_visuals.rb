module AbuseNoticeParser
  class CustomVisuals < VpsAdmin::API::IncidentReports::Parser
    ORIGINATOR = 'abuse@customvisuals.com'.freeze
    TIMESTAMP_PREFIX = /(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2}(?:\.\d+)?)([+-]\d{2}:?\d{2})(?:\s|\z)/

    def self.match_message?(subject, from, message:, check_sender: true)
      subject.start_with?('Abuse detected from IP ') && (!check_sender || from == ORIGINATOR)
    end

    include Utils

    attr_reader :processed
    alias processed? processed

    def parse
      @processed = false
      subject = /\AAbuse detected from IP (\S+)\z/.match(strip_rt_prefix(message.subject))
      notice_error('missing source in provider subject') if subject.nil?
      source = notice_ip(subject[1])
      body = notice_body
      records = body.scan(/^The log line for the last record is:\s*\n(.*?)(?:\n\s*\n|\z)/m).flatten
      notice_error('expected one last-record section') unless records.length == 1
      notice_error('competing last records') unless records.first.scan(/^#{TIMESTAMP_PREFIX}/).length == 1
      match = /\A#{TIMESTAMP_PREFIX}/.match(records.first)
      notice_error('missing complete last-record timestamp and numeric offset') if match.nil?
      time = notice_time("#{match[1]}T#{match[2]}#{match[3]}")
      incidents = notice_incident(source, time, notice_text)
      @processed = true
      incidents
    rescue NoticeError => e
      notice_warning('Custom Visuals', e.message)
      []
    end
  end
end
