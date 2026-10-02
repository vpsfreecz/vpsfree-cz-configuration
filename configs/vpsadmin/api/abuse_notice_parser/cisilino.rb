module AbuseNoticeParser
  class Cisilino < VpsAdmin::API::IncidentReports::Parser
    ORIGINATOR = 'notifiche@cisilino.com'.freeze

    def self.match_message?(subject, from, message:, check_sender: true)
      subject.start_with?('Abuse report - IP ') && (!check_sender || from == ORIGINATOR)
    end

    include Utils

    attr_reader :processed
    alias processed? processed

    def parse
      @processed = false
      subject = %r{\AAbuse report - IP (\S+) / Segnalazione abuso - IP (\S+)\z}.match(strip_rt_prefix(message.subject))
      notice_error('missing source in provider subject') if subject.nil?
      source = notice_ip(subject[1])
      corroborate_notice_source(source, [subject[2]])
      fields = notice_fields(notice_body, keys: ['Last seen'])
      time = notice_utc_time(required_notice_field(fields, 'Last seen'))
      incidents = notice_incident(source, time, notice_text)
      @processed = true
      incidents
    rescue NoticeError => e
      notice_warning('Cisilino', e.message)
      []
    end
  end
end
