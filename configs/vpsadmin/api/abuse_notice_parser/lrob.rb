require 'json'

module AbuseNoticeParser
  class Lrob < VpsAdmin::API::IncidentReports::Parser
    ORIGINATOR = 'abusereport@lrob.net'.freeze

    def self.match_message?(subject, from, message:, check_sender: true)
      subject.start_with?('Abuse report for IP ') && (!check_sender || from == ORIGINATOR)
    end

    include Utils

    attr_reader :processed
    alias processed? processed

    def parse
      @processed = false
      parts = message.parts.select { |part| part.filename.to_s.casecmp?('xarf.json') }
      notice_error('expected one top-level application/json xarf.json') unless parts.length == 1 && parts.first.mime_type == 'application/json'
      json = bounded_notice_text(parts.first.decoded)
      data = JSON.parse(json, allow_duplicate_key: false)
      notice_error('unsupported LRob JSON version or shape') unless data.is_a?(Hash) && data['xarf_version'] == '4.2.0'
      report = XArfDecoder.new.decode(json)
      unless report.version == '4.2.0' && report.report_class == 'connection' && report.report_type == 'login_attack'
        notice_error('unsupported LRob report profile')
      end
      organizations = %w[sender reporter].map { |key| data.fetch(key) }
      unless organizations.all? do |organization|
        organization.fetch('contact').match?(/\A[^@\s]+@[^@\s]+\z/) \
          && organization.fetch('domain').match?(/\A[a-z0-9.-]+\.[a-z]+\z/i)
      end
        notice_error('invalid JSON sender/reporter contact metadata')
      end
      trusted_organizations = organizations.all? do |organization|
        organization.fetch('domain') == 'lrob.net' && organization.fetch('contact') == ORIGINATOR
      end
      if sender_check_enabled? && (message['X-RT-Originator'].to_s != ORIGINATOR || !trusted_organizations)
        notice_error('RT originator and JSON sender/reporter do not match')
      end
      source = report.source_ip
      time = notice_time(data.fetch('timestamp'))
      corroborate_notice_subject(source, /\AAbuse report for IP (\S+) - /)
      evidence = report.evidence.map do |item|
        notice_error('unsupported JSON evidence type') unless item.content_type == 'text/plain'

        bounded_notice_text(item.payload)
      end
      incidents = notice_incident(source, time, notice_text(evidence: evidence))
      @processed = true
      incidents
    rescue NoticeError, XArfDecoder::Error, JSON::ParserError => e
      notice_warning('LRob/Shieldlist', e.is_a?(JSON::ParserError) ? 'invalid JSON' : e.message)
      []
    end
  end
end
