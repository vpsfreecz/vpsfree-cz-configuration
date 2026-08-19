require 'ipaddr'
require 'json'
require 'time'

module AbuseNoticeParser
  class XArfDecoder
    MAX_EVIDENCE_BYTES = 1024 * 1024

    Evidence = Data.define(:content_type, :description, :payload)
    Report = Data.define(
      :version,
      :source_ip,
      :detected_at,
      :report_class,
      :report_type,
      :report_subtype,
      :protocol,
      :source_port,
      :evidence_source,
      :smtp_mail_from,
      :report_id,
      :disclosure,
      :sender_domain,
      :evidence
    )

    class Error < StandardError; end

    def decode(json)
      data = JSON.parse(json)

      unless data.is_a?(Hash)
        raise Error, 'top-level JSON value is not an object'
      end

      has_v3 = data.has_key?('Version')
      has_v4 = data.has_key?('xarf_version')

      if has_v3 == has_v4
        raise Error, 'expected exactly one XARF version field'
      end

      has_v3 ? decode_v3(data) : decode_v4(data)
    rescue JSON::ParserError => e
      raise Error, "invalid JSON: #{e.message}"
    end

    protected

    def decode_v3(data)
      version = required_string(data, 'Version')
      raise Error, "unsupported XARF version #{version.inspect}" unless version == '3'

      disclosure = data['Disclosure']
      unless [true, false].include?(disclosure)
        raise Error, 'Disclosure is not a boolean'
      end

      reporter = required_hash(data, 'ReporterInfo')
      sender_domain = required_string(reporter, 'ReporterOrgDomain')
      report = required_hash(data, 'Report')
      evidence = decode_v3_evidence(report)

      Report.new(
        version: version,
        source_ip: parse_ip(required_string(report, 'SourceIp')),
        detected_at: parse_time(required_string(report, 'Date')),
        report_class: required_string(report, 'ReportClass'),
        report_type: required_string(report, 'ReportType'),
        report_subtype: optional_string(report, 'ReportSubType'),
        protocol: nil,
        source_port: nil,
        evidence_source: nil,
        smtp_mail_from: optional_email(report, 'SmtpMailFromAddress'),
        report_id: nil,
        disclosure: disclosure,
        sender_domain: sender_domain.downcase,
        evidence: evidence
      )
    end

    def decode_v3_evidence(report)
      sample = report['Sample']
      samples = report['Samples']

      if sample && samples
        raise Error, 'Report contains both Sample and Samples'
      elsif sample
        [decode_v3_sample(required_hash(report, 'Sample'))]
      elsif samples
        unless samples.is_a?(Array)
          raise Error, 'Report.Samples is not an array'
        end

        samples.map.with_index do |item, index|
          decode_v3_sample(hash_value(item, "Report.Samples[#{index}]"))
        end
      else
        []
      end.then { |evidence| check_evidence_size(evidence) }
    end

    def decode_v3_sample(sample)
      base64_encoded = sample.fetch('Base64Encoded', false)
      unless [true, false].include?(base64_encoded)
        raise Error, 'evidence Base64Encoded is not a boolean'
      end

      payload = required_string(sample, 'Payload', allow_empty: true)

      Evidence.new(
        content_type: required_string(sample, 'ContentType').downcase,
        description: optional_string(sample, 'Description'),
        payload: decode_payload(payload, base64_encoded: base64_encoded)
      )
    end

    def decode_v4(data)
      version = required_string(data, 'xarf_version')
      unless version.match?(/\A4\.\d+\.\d+\z/)
        raise Error, "unsupported XARF version #{version.inspect}"
      end

      report_id = required_string(data, 'report_id')
      unless report_id.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
        raise Error, 'report_id is not a UUID v4'
      end

      required_organization(data, 'reporter')
      sender = required_organization(data, 'sender')
      evidence = decode_v4_evidence(data)

      Report.new(
        version: version,
        source_ip: parse_ip(required_string(data, 'source_identifier')),
        detected_at: parse_time(required_string(data, 'timestamp')),
        report_class: required_string(data, 'category'),
        report_type: required_string(data, 'type'),
        report_subtype: nil,
        protocol: optional_string(data, 'protocol'),
        source_port: optional_port(data, 'source_port'),
        evidence_source: optional_string(data, 'evidence_source'),
        smtp_mail_from: optional_email(data, 'smtp_from'),
        report_id: report_id,
        disclosure: nil,
        sender_domain: required_string(sender, 'domain').downcase,
        evidence: evidence
      )
    end

    def decode_v4_evidence(data)
      items = data.fetch('evidence', [])
      raise Error, 'evidence is not an array' unless items.is_a?(Array)

      evidence = items.map.with_index do |item, index|
        item = hash_value(item, "evidence[#{index}]")

        Evidence.new(
          content_type: required_string(item, 'content_type').downcase,
          description: optional_string(item, 'description'),
          payload: decode_payload(
            required_string(item, 'payload', allow_empty: true),
            base64_encoded: true
          )
        )
      end

      check_evidence_size(evidence)
    end

    def required_organization(data, key)
      organization = required_hash(data, key)
      required_string(organization, 'org')
      required_string(organization, 'contact')
      required_string(organization, 'domain')
      organization
    end

    def required_hash(data, key)
      hash_value(data[key], key)
    end

    def hash_value(value, label)
      raise Error, "#{label} is not an object" unless value.is_a?(Hash)

      value
    end

    def required_string(data, key, allow_empty: false)
      value = data[key]
      unless value.is_a?(String) && (allow_empty || !value.empty?)
        raise Error, "#{key} is not a valid string"
      end

      value
    end

    def optional_string(data, key)
      value = data[key]
      return nil if value.nil?
      raise Error, "#{key} is not a valid string" unless value.is_a?(String) && !value.empty?

      value
    end

    def optional_email(data, key)
      value = optional_string(data, key)
      return nil if value.nil?

      if value.bytesize > 320 || value.match?(/[\r\n]/)
        raise Error, "#{key} is not a valid email address"
      end

      value
    end

    def optional_port(data, key)
      value = data[key]
      return nil if value.nil?

      unless value.is_a?(Integer) && value.between?(1, 65_535)
        raise Error, "#{key} is not a valid port"
      end

      value
    end

    def parse_ip(value)
      raise Error, 'source identifier is a network prefix' if value.include?('/')

      IPAddr.new(value).to_s
    rescue IPAddr::InvalidAddressError
      raise Error, 'source identifier is not an IP address'
    end

    def parse_time(value)
      raise Error, 'event timestamp is not a date-time' unless value.include?('T')
      unless value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/i)
        raise Error, 'event timestamp does not include a UTC offset'
      end

      Time.iso8601(value)
    rescue ArgumentError
      raise Error, 'event timestamp is not valid ISO 8601'
    end

    def decode_payload(payload, base64_encoded:)
      return payload unless base64_encoded

      payload.unpack1('m0')
    rescue ArgumentError
      raise Error, 'evidence payload is not valid Base64'
    end

    def check_evidence_size(evidence)
      size = evidence.sum { |item| item.payload.bytesize }
      raise Error, 'decoded evidence is too large' if size > MAX_EVIDENCE_BYTES

      evidence
    end
  end
end
