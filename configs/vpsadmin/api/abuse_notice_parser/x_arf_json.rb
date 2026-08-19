module AbuseNoticeParser
  class XArfJson < VpsAdmin::API::IncidentReports::Parser
    MAX_JSON_BYTES = 1024 * 1024
    ALLOWED_EVIDENCE_TYPES = %w[message/rfc822 text/plain].freeze
    TRUSTED_ORIGINATORS = {
      'support@abusix.com' => 'abusix.com'
    }.freeze

    def self.match_message?(_subject, from, message:, check_sender: true)
      return false if check_sender && !TRUSTED_ORIGINATORS.has_key?(from)

      !xarf_json_part(message).nil?
    end

    def self.xarf_json_part(message)
      feedback_parts = message.all_parts.select do |part|
        part.mime_type == 'message/feedback-report'
      end
      json_parts = message.all_parts.select do |part|
        part.mime_type == 'application/json' \
          && part.filename.to_s.casecmp?('xarf.json')
      end

      return nil unless feedback_parts.length == 1 && json_parts.length == 1
      return nil unless feedback_parts.first.decoded.match?(/^Feedback-Type:\s*xarf\s*$/i)

      json_parts.first
    end

    def parse
      json_part = self.class.xarf_json_part(message)

      if json_part.nil?
        warn 'XARF JSON: expected one feedback part and one xarf.json attachment'
        return []
      end

      json = json_part.decoded

      if json.bytesize > MAX_JSON_BYTES
        warn 'XARF JSON: attachment is too large'
        return []
      end

      report = XArfDecoder.new.decode(json)

      unless trusted_report_sender?(report)
        warn 'XARF JSON: RT originator and report sender do not match'
        return []
      end

      unless supported_report_type?(report)
        warn "XARF JSON: unsupported report type #{report.report_class}/#{report.report_type}"
        return []
      end

      evidence = report.evidence.select do |item|
        ALLOWED_EVIDENCE_TYPES.include?(item.content_type)
      end

      if evidence.empty?
        warn 'XARF JSON: no supported textual evidence found'
        return []
      end

      assignment = find_ip_address_assignment(report.source_ip, time: report.detected_at)

      if assignment.nil?
        warn "XARF JSON: IP #{report.source_ip} not found"
        return []
      end

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: "Spam report for #{report.source_ip}",
        text: render_text(report, evidence),
        detected_at: report.detected_at
      )

      incident.save! unless dry_run?
      [incident]
    rescue XArfDecoder::Error => e
      warn "XARF JSON: #{e.message}"
      []
    end

    protected

    def sender_check_enabled?
      return true unless ENV.has_key?('CHECK_SENDER')

      %w[y yes 1].include?(ENV.fetch('CHECK_SENDER'))
    end

    def trusted_report_sender?(report)
      return true unless sender_check_enabled?

      expected_domain = TRUSTED_ORIGINATORS[message['X-RT-Originator'].to_s]
      expected_domain == report.sender_domain
    end

    def supported_report_type?(report)
      if report.version == '3'
        report.report_class == 'Activity' \
          && report.report_type == 'Spam' \
          && report.report_subtype == 'Trap'
      else
        report.report_class == 'messaging' \
          && report.report_type == 'spam' \
          && report.protocol == 'smtp' \
          && report.evidence_source == 'spamtrap' \
          && !report.smtp_mail_from.nil? \
          && !report.source_port.nil?
      end
    end

    def render_text(report, evidence)
      lines = [
        'A spam trap received an email from this IP address.',
        '',
        "Source IP: #{report.source_ip}",
        "Detected at: #{report.detected_at.utc.iso8601}"
      ]
      lines << "Envelope sender: #{report.smtp_mail_from}" if report.smtp_mail_from
      lines << "Report ID: #{report.report_id}" if report.report_id
      lines << ''
      lines << 'Reported message:'
      lines << ''
      lines << evidence.map { |item| evidence_text(item) }.join("\n\n")
      lines.join("\n")
    end

    def evidence_text(evidence)
      evidence.payload
              .encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
              .delete("\u0000")
              .strip
    end
  end
end
