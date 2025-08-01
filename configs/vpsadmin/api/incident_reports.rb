require 'require_all'

module AbuseNoticeParser; end

require_relative 'abuse_notice_parser/utils'
require_rel 'abuse_notice_parser/*.rb'

VpsAdmin::API::IncidentReports.config do
  handle_message do |mailbox, message, dry_run:|
    check_sender = ENV['CHECK_SENDER'] ? %w[y yes 1].include?(ENV['CHECK_SENDER']) : true
    originator = message['X-RT-Originator'].to_s

    if /^\[rt\.vpsfree\.cz \#\d+\] ([^$]+)/ !~ message.subject
      warn "#{mailbox.label}: invalid message subject=#{message.subject.inspect}, originator=#{originator.inspect}"
      next
    end

    subject = Regexp.last_match(1)
    processed = false
    incidents = []

    [
      AbuseNoticeParser::BitNinja,
      AbuseNoticeParser::Fail2Ban,
      AbuseNoticeParser::LeakIX,
      AbuseNoticeParser::Proki,
      AbuseNoticeParser::SpamCop,
      AbuseNoticeParser::UsGo
    ].each do |klass|
      if !klass.match_subject?(subject) \
         || (check_sender && !klass.match_sender?(originator))
        next
      end

      processed = true

      parser = klass.new(mailbox, message, dry_run: dry_run)
      incidents = parser.parse

      break
    end

    unless processed
      warn "#{mailbox.label}: unidentified message subject=#{message.subject.inspect}, originator=#{originator.inspect}"
    end

    VpsAdmin::API::IncidentReports::Result.new(
      incidents: incidents,
      reply: {
        from: 'vpsadmin@vpsfree.cz',
        to: ['abuse-komentare@vpsfree.cz']
      },
      processed: processed
    )
  end
end
