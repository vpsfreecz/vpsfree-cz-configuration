# frozen_string_literal: true

require 'fileutils'
require 'ripper'
require 'yaml'

module VpsAdminConfig
  module EventI18n
    class Catalog
      DEFAULT_LOCALE = 'en'
      LOCALES = %w[en cs].freeze
      MONITORING_PATH = 'configs/vpsadmin/api/monitoring.rb'
      LOCALE_DIR = 'configs/vpsadmin/api/locales'
      HEADER = <<~HEADER
        # This file is maintained by rake vpsadmin:events:i18n:update.
        # Event labels are generated from configs/vpsadmin/api/monitoring.rb.
        # Edit translations here, then rerun rake vpsadmin:events:i18n:update.
      HEADER

      Event = Struct.new(:name, :label, :line, keyword_init: true)
      Token = Struct.new(:line, :column, :type, :text, keyword_init: true)
      Extraction = Struct.new(:events, :errors, keyword_init: true)

      IGNORED_TOKEN_TYPES = %i[on_sp on_ignored_nl on_nl on_comment].freeze

      def initialize(root:, monitoring_path: MONITORING_PATH, locale_dir: LOCALE_DIR)
        @root = root
        @monitoring_path = monitoring_path
        @locale_dir = locale_dir
      end

      def events
        extraction.events
      end

      def update!
        raise errors_message(extraction.errors) if extraction.errors.any?

        FileUtils.mkdir_p(absolute_path(locale_dir))
        normalized_catalog(add_missing: true).each do |locale, data|
          File.write(locale_file(locale), render_locale(locale, data))
        end
      end

      def check!
        errors = extraction.errors.dup
        expected = normalized_catalog(add_missing: true)

        LOCALES.each do |locale|
          path = locale_file(locale)
          unless File.exist?(path)
            errors << "#{relative_path(path)}: locale file is missing"
            next
          end

          data = locale_data.fetch(locale, {})
          types = event_types(data)
          expected_types = expected_type_keys

          expected_types.each do |key|
            label = types.dig(key, 'label')
            if label.nil?
              errors << "#{locale}: missing vpsadmin.events.types.#{key}.label"
            elsif locale != DEFAULT_LOCALE && todo?(label)
              errors << "#{locale}: missing translation for vpsadmin.events.types.#{key}.label"
            end
          end

          (types.keys - expected_types).sort.each do |key|
            errors << "#{locale}: unused vpsadmin.events.types.#{key}"
          end

          if File.read(path) != render_locale(locale, expected.fetch(locale))
            errors << "#{relative_path(path)}: not normalized; run rake vpsadmin:events:i18n:update"
          end
        end

        raise errors_message(errors) if errors.any?

        true
      end

      private

      attr_reader :root, :monitoring_path, :locale_dir

      def extraction
        @extraction ||= begin
          result = extract_events(File.read(absolute_path(monitoring_path)))
          duplicates = result.events.group_by(&:name).select { |_, list| list.length > 1 }
          duplicates.each do |name, list|
            lines = list.map(&:line).join(', ')
            result.errors << "duplicate alert_event #{name.inspect} on lines #{lines}"
          end
          result
        end
      end

      def extract_events(content)
        tokens = significant_tokens(content)
        events = []
        errors = []
        index = 0

        while index < tokens.length
          token = tokens[index]
          unless token.type == :on_ident && token.text == 'alert_event'
            index += 1
            next
          end

          name, after_name = parse_string(tokens, index + 1, "alert_event on line #{token.line}", errors)
          label = nil
          label_index = after_name
          index = after_name

          while index < tokens.length
            current = tokens[index]
            break if current.type == :on_ident && current.text == 'alert_event'

            if current.type == :on_label && current.text == 'label:'
              label, label_index = parse_string(tokens, index + 1, "label for alert_event #{name.inspect}", errors)
              break
            end

            index += 1
          end

          errors << "alert_event #{name.inspect} on line #{token.line} is missing a label" if name && label.nil?
          events << Event.new(name:, label:, line: token.line) if name && label
          index = [index, label_index].max
        end

        Extraction.new(events:, errors:)
      end

      def significant_tokens(content)
        Ripper.lex(content).filter_map do |(line, column), type, text, _state|
          next if IGNORED_TOKEN_TYPES.include?(type)

          Token.new(line:, column:, type:, text:)
        end
      end

      def parse_string(tokens, index, context, errors)
        token = tokens[index]
        unless token&.type == :on_tstring_beg
          line = token&.line || 'EOF'
          errors << "#{context} must use a plain string literal near line #{line}"
          return [nil, index + 1]
        end

        value = +''
        index += 1

        while index < tokens.length
          token = tokens[index]
          case token.type
          when :on_tstring_content
            value << token.text
          when :on_tstring_end
            return [value, index + 1]
          else
            errors << "#{context} must use a plain string literal near line #{token.line}"
            return [nil, index + 1]
          end
          index += 1
        end

        errors << "#{context} has an unterminated string literal"
        [nil, index]
      end

      def normalized_catalog(add_missing:)
        LOCALES.to_h do |locale|
          types = {}
          extraction.events.each do |event|
            key = i18n_key_fragment(event.name)
            label =
              if locale == DEFAULT_LOCALE
                event.label
              else
                event_types(locale_data.fetch(locale, {})).dig(key, 'label') ||
                  (add_missing ? 'TODO' : nil)
              end
            types[key] = { 'label' => label } if label
          end

          [
            locale,
            {
              'vpsadmin' => {
                'events' => {
                  'types' => types
                }
              }
            }
          ]
        end
      end

      def locale_data
        @locale_data ||= LOCALES.to_h do |locale|
          path = locale_file(locale)
          data = File.exist?(path) ? YAML.safe_load_file(path, aliases: true) || {} : {}
          [locale, data.fetch(locale, {})]
        end
      end

      def event_types(data)
        data.dig('vpsadmin', 'events', 'types') || {}
      end

      def expected_type_keys
        extraction.events.map { |event| i18n_key_fragment(event.name) }
      end

      def i18n_key_fragment(value)
        value.to_s.tr('.', '_')
      end

      def todo?(value)
        value.to_s.strip.empty? || value.to_s.match?(/\ATODO\b/i)
      end

      def render_locale(locale, data)
        HEADER + YAML.dump(locale => data)
      end

      def locale_file(locale)
        absolute_path(File.join(locale_dir, "#{locale}.yml"))
      end

      def absolute_path(path)
        File.join(root, path)
      end

      def relative_path(path)
        path.delete_prefix("#{root}/")
      end

      def errors_message(errors)
        "vpsAdmin event i18n health check failed:\n#{errors.join("\n")}"
      end
    end
  end
end
