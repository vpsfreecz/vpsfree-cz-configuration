# frozen_string_literal: true

require 'bundler/setup'
require 'mail'
require 'rspec'

module VpsAdmin
  module API
    module IncidentReports
      class Result
        attr_reader :incidents, :reply, :processed
        alias processed? processed

        def initialize(incidents:, reply: nil, processed: nil)
          @incidents = incidents
          @reply = reply
          @processed = processed.nil? ? incidents.any? : processed
        end
      end

      class Config
        def initialize(&)
          instance_exec(&)
        end

        def handle_message(&block)
          @handle_message = block
        end

        def call(mailbox, message, dry_run:)
          @handle_message.call(mailbox, message, dry_run: dry_run)
        end
      end

      class << self
        attr_reader :config_instance

        def config(&)
          @config_instance = Config.new(&)
        end

        def handle_message(mailbox, message, dry_run:)
          config_instance.call(mailbox, message, dry_run: dry_run)
        end
      end

      class Parser
        attr_reader :mailbox, :message, :dry_run
        alias dry_run? dry_run

        def initialize(mailbox, message, dry_run:)
          @mailbox = mailbox
          @message = message
          @dry_run = dry_run
        end

        protected

        def find_ip_address_assignment(addr_str, time: nil)
          AbuseNoticeParserSpec::AssignmentRegistry.find(addr_str, time: time)
        end
      end
    end
  end
end

module AbuseNoticeParserSpec
  FIXTURE_ROOT = File.expand_path('fixtures/emails', __dir__)

  Assignment = Struct.new(:id, :user_id, :vps_id, :ip_addr, keyword_init: true)

  module AssignmentRegistry
    class << self
      attr_reader :lookups

      def reset!
        @assignments = {}
        @lookups = []
        @next_id = 3000
      end

      def register(ip, user_id: 1001, vps_id: 2002)
        @next_id += 1
        @assignments[ip] = Assignment.new(
          id: @next_id,
          user_id: user_id,
          vps_id: vps_id,
          ip_addr: ip
        )
      end

      def find(addr_str, time: nil)
        @lookups << { addr_str: addr_str, time: time }
        @assignments[addr_str]
      end
    end
  end

  class Relation
    def initialize(record)
      @record = record
    end

    def order(*)
      self
    end

    def take
      @record
    end
  end

  def fixture_message(name)
    path = File.join(FIXTURE_ROOT, "#{name}.eml")
    raise "Missing fixture #{path}" unless File.exist?(path)

    Mail.read(path)
  end

  def mailbox
    @mailbox ||= Struct.new(:label).new('abuse')
  end

  def register_assignment(ip, user_id: 1001, vps_id: 2002)
    AssignmentRegistry.register(ip, user_id: user_id, vps_id: vps_id)
  end

  def parse_fixture(parser_class, name, assignments:, dry_run: true)
    assignments.each { |ip| register_assignment(ip) }
    parser_class.new(mailbox, fixture_message(name), dry_run: dry_run).parse
  end
end

ObjectStateRecord = Struct.new(:object_state, keyword_init: true)

class IncidentReport
  class << self
    attr_accessor :existing_report
    attr_reader :records, :where_calls

    def reset!
      @records = []
      @where_calls = []
      @existing_report = nil
    end

    def where(attrs)
      @where_calls << attrs
      AbuseNoticeParserSpec::Relation.new(@existing_report)
    end
  end

  attr_accessor :id, :user_id, :vps_id, :ip_address_assignment,
                :ip_address_assignment_id, :mailbox, :subject, :text,
                :codename, :detected_at, :created_at, :saved

  def initialize(attrs = {})
    attrs.each { |key, value| public_send("#{key}=", value) }
    self.ip_address_assignment_id ||= ip_address_assignment&.id
    self.created_at ||= Time.now
    self.saved = false
  end

  def save!
    self.saved = true
    self.class.records << self
    true
  end

  def user
    ObjectStateRecord.new(object_state: 'active')
  end

  def vps
    ObjectStateRecord.new(object_state: 'active')
  end
end

AbuseNoticeParserSpec::AssignmentRegistry.reset!
IncidentReport.reset!

parser_dir = File.expand_path('../configs/vpsadmin/api/abuse_notice_parser', __dir__)
require File.join(parser_dir, 'utils')
Dir[File.join(parser_dir, '*.rb')].each do |path|
  next if File.basename(path) == 'utils.rb'

  require path
end

RSpec.configure do |config|
  config.order = :random
  Kernel.srand config.seed

  config.include AbuseNoticeParserSpec

  config.before do
    AbuseNoticeParserSpec::AssignmentRegistry.reset!
    IncidentReport.reset!
  end
end
