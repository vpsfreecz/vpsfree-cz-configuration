require 'ipaddr'
require 'uri'

module AbuseNoticeParser
  class XArfJson < VpsAdmin::API::IncidentReports::Parser
    MAX_JSON_BYTES = 1024 * 1024
    MAX_SUBJECT_CHARACTERS = 255
    MAX_TEXT_BYTES = 65_535
    ALLOWED_EVIDENCE_TYPES = %w[message/rfc822 text/plain].freeze
    ABUSIX_ORIGINATOR = 'support@abusix.com'.freeze
    NETCRAFT_CASE_ID = /\A\d{1,32}\z/
    NETCRAFT_CONTENT_TYPE_MAX_CHARACTERS = 64
    NETCRAFT_SOURCE_URL_MAX_BYTES = 4096
    UNSAFE_DISPLAY_CHARACTERS = /[\p{Cc}\p{Cf}\p{Zl}\p{Zp}]/
    UNICODE_SEPARATOR_AT_EDGE = /\A\p{Z}|\p{Z}\z/
    NETCRAFT_ORIGINATOR =
      /\Atakedown-response\+(?<case_id>\d{1,32})@netcraft\.com\z/i

    attr_reader :processed
    alias processed? processed

    def self.match_message?(_subject, from, message:, check_sender: true)
      return false if check_sender && !trusted_originator?(from)

      !xarf_json_part(message).nil?
    end

    def self.trusted_originator?(from)
      from == ABUSIX_ORIGINATOR || NETCRAFT_ORIGINATOR.match?(from)
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
      @processed = legacy_abusix_processed?(nil)
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
      @processed = legacy_abusix_processed?(report.version)
      provider = report_provider(report)

      if provider.nil?
        warn 'XARF JSON: unsupported report type'
        return []
      end

      unless trusted_report_sender?(provider, report)
        warn 'XARF JSON: RT originator and report sender do not match'
        return []
      end

      evidence = supported_evidence(provider, report)
      return [] if evidence.nil?

      subject = render_subject(provider, report)
      text = render_text(provider, report, evidence)

      unless persistable_incident?(subject, text)
        return []
      end

      @processed = true
      assignment = find_ip_address_assignment(report.source_ip, time: report.detected_at)

      if assignment.nil?
        warn "XARF JSON: IP #{report.source_ip} not found"
        return []
      end

      if provider == :netcraft && duplicate_incident?(assignment, report, subject)
        return []
      end

      incident = ::IncidentReport.new(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment: assignment,
        mailbox: mailbox,
        subject: subject,
        text: text,
        detected_at: report.detected_at
      )

      incident.save! unless dry_run?
      [incident]
    rescue XArfDecoder::Error => e
      @processed = legacy_abusix_processed?(e.version)
      warn "XARF JSON: #{e.message}"
      []
    end

    protected

    def sender_check_enabled?
      return true unless ENV.has_key?('CHECK_SENDER')

      %w[y yes 1].include?(ENV.fetch('CHECK_SENDER'))
    end

    def legacy_abusix_processed?(version)
      message['X-RT-Originator'].to_s == ABUSIX_ORIGINATOR \
        && version != '1'
    end

    def trusted_report_sender?(provider, report)
      return true unless sender_check_enabled?

      originator = message['X-RT-Originator'].to_s

      if provider == :abusix
        originator == ABUSIX_ORIGINATOR \
          && report.sender_domain == 'abusix.com'
      elsif provider == :netcraft \
            && (match = NETCRAFT_ORIGINATOR.match(originator))
        report.sender_domain == 'netcraft.com' \
          && report.reporter_email&.casecmp?(originator) \
          && report.report_id == match[:case_id]
      else
        false
      end
    end

    def report_provider(report)
      if netcraft_report?(report)
        :netcraft
      elsif abusix_report?(report)
        :abusix
      end
    end

    def abusix_report?(report)
      case report.version
      when '3'
        report.report_class == 'Activity' \
          && report.report_type == 'Spam' \
          && report.report_subtype == 'Trap'
      when /\A4\./
        report.report_class == 'messaging' \
          && report.report_type == 'spam' \
          && report.protocol == 'smtp' \
          && report.evidence_source == 'spamtrap' \
          && !report.smtp_mail_from.nil? \
          && !report.source_port.nil?
      else
        false
      end
    end

    def netcraft_report?(report)
      report.version == '1' \
        && report.report_id&.match?(NETCRAFT_CASE_ID) \
        && report.disclosure == true \
        && (netcraft_extortion_report?(report) || netcraft_content_report?(report))
    end

    def netcraft_extortion_report?(report)
      report.report_class == 'Activity' \
        && report.report_type == 'Spam' \
        && report.report_subtype == 'Extortion Mail Server'
    end

    def netcraft_content_report?(report)
      report.report_class == 'Content' \
        && safe_netcraft_content_type?(report.report_type) \
        && valid_netcraft_source_url?(report.source_url)
    end

    def safe_netcraft_content_type?(value)
      value.length.between?(1, NETCRAFT_CONTENT_TYPE_MAX_CHARACTERS) \
        && !value.match?(UNSAFE_DISPLAY_CHARACTERS) \
        && !value.match?(UNICODE_SEPARATOR_AT_EDGE) \
        && value.match?(/[^\p{Z}]/)
    end

    def valid_netcraft_source_url?(value)
      return false if value.nil? || value.bytesize > NETCRAFT_SOURCE_URL_MAX_BYTES
      return false if value != value.strip || value.match?(UNSAFE_DISPLAY_CHARACTERS)

      uri = URI.parse(value)
      uri.is_a?(URI::HTTP) \
        && %w[http https].include?(uri.scheme&.downcase) \
        && uri.userinfo.nil? \
        && uri.port.between?(1, 65_535) \
        && valid_netcraft_url_host?(uri.hostname)
    rescue URI::InvalidComponentError, URI::InvalidURIError
      false
    end

    def valid_netcraft_url_host?(host)
      return false if host.nil? || host.empty?

      begin
        IPAddr.new(host)
        return true
      rescue IPAddr::InvalidAddressError
        # Continue with hostname validation.
      end

      return false if host.match?(/\A[\d.]+\z/)

      hostname = host.delete_suffix('.')
      return false if hostname.empty? || hostname.bytesize > 253

      hostname.split('.', -1).all? do |label|
        label.bytesize <= 63 \
          && label.match?(/\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/i)
      end
    end

    def supported_evidence(provider, report)
      if provider == :netcraft
        required = netcraft_extortion_report?(report)
        valid = (!required || !report.evidence.empty?) && report.evidence.all? do |item|
          ALLOWED_EVIDENCE_TYPES.include?(item.content_type) \
            && !safe_text(item.payload).empty?
        end

        unless valid
          warn 'XARF JSON: Netcraft evidence is incomplete or unsupported'
          return
        end

        report.evidence
      else
        evidence = report.evidence.select do |item|
          ALLOWED_EVIDENCE_TYPES.include?(item.content_type)
        end

        if evidence.empty?
          warn 'XARF JSON: no supported textual evidence found'
          return
        end

        evidence
      end
    end

    def persistable_incident?(subject, text)
      if subject.length > MAX_SUBJECT_CHARACTERS
        warn 'XARF JSON: incident subject is too long'
        false
      elsif text.bytesize > MAX_TEXT_BYTES
        warn 'XARF JSON: incident text is too long'
        false
      elsif !utf8mb3_compatible?(subject) || !utf8mb3_compatible?(text)
        warn 'XARF JSON: incident contains characters unsupported by the database'
        false
      else
        true
      end
    end

    def utf8mb3_compatible?(text)
      text.each_codepoint.none? { |codepoint| codepoint > 0xffff }
    end

    def render_subject(provider, report)
      if provider == :netcraft
        # The exact subject is also the persisted duplicate key. Keep it stable
        # across deployments unless the lookup strategy is migrated first.
        type = if netcraft_content_report?(report)
                 report.report_type
               else
                 report.report_subtype
               end
        "Netcraft issue #{report.report_id}: #{type} at #{report.source_ip}"
      else
        "Spam report for #{report.source_ip}"
      end
    end

    def render_text(provider, report, evidence)
      return render_netcraft_text(report, evidence) if provider == :netcraft

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

    def render_netcraft_text(report, evidence)
      return render_netcraft_content_text(report, evidence) if netcraft_content_report?(report)

      lines = [
        'Netcraft reported this IP address as an email server sending extortion messages.',
        '',
        "Source IP: #{report.source_ip}",
        "Detected at: #{report.detected_at.utc.iso8601}",
        "Netcraft issue: #{report.report_id}"
      ]
      lines << "Details: #{safe_text(report.report_notes)}" if report.report_notes
      lines << ''
      lines << 'Reported message:'
      lines << ''
      lines << evidence.map { |item| evidence_text(item) }.join("\n\n")
      lines.join("\n")
    end

    def render_netcraft_content_text(report, evidence)
      lines = [
        'Netcraft reported harmful content hosted at this IP address.',
        '',
        "Source IP: #{report.source_ip}",
        "Detected at: #{report.detected_at.utc.iso8601}",
        "Netcraft issue: #{report.report_id}",
        "Report type: #{report.report_type}",
        "Reported URL: #{report.source_url}"
      ]
      lines << "Details: #{safe_text(report.report_notes)}" if report.report_notes

      unless evidence.empty?
        lines << ''
        lines << 'Reported evidence:'
        lines << ''
        lines << evidence.map { |item| evidence_text(item) }.join("\n\n")
      end

      lines.join("\n")
    end

    def duplicate_incident?(assignment, report, subject)
      existing = ::IncidentReport.where(
        user_id: assignment.user_id,
        vps_id: assignment.vps_id,
        ip_address_assignment_id: assignment.id,
        subject: subject,
        detected_at: report.detected_at
      ).order('created_at DESC').take

      return false if existing.nil?

      warn "XARF JSON: found previous Netcraft incident ##{existing.id} " \
           "for report #{report.report_id}"
      true
    end

    def evidence_text(evidence)
      safe_text(evidence.payload)
    end

    def safe_text(text)
      text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
          .delete("\u0000")
          .strip
    end
  end
end
