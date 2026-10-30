# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'

RSpec.describe VpsAdmin::API do
  let(:server) do
    fixture = Class.new do
      attr_accessor :documentation_name
      attr_reader :extensions

      def documentation_oauth(**options)
        options
      end
    end
    instance_spy(fixture, extensions: [])
  end
  let(:mailer) { Object.new }
  let(:runtime_root) { Dir.mktmpdir('vpsadmin-docs-hook-') }
  let(:settings) do
    {
      'client_id' => 'synthetic-docs-client',
      'client_secret' => 'synthetic-private-value',
      'redirect_uri' => 'https://api.example.test/_documentation/oauth/callback'
    }
  end
  let(:session_key) { 'k' * 64 }

  after do
    FileUtils.remove_entry(runtime_root)
  end

  before do
    Dir.mkdir(File.join(runtime_root, 'config'))
    stub_const('HaveAPI::Extensions::ExceptionMailer', Class.new)
    allow(HaveAPI::Extensions::ExceptionMailer).to receive(:new).and_return(mailer)
    stub_const('SysConfig', Class.new)
    allow(SysConfig).to receive(:get).with(:core, :api_url).and_return('https://api.example.test')
    allow(described_class).to receive(:root).and_return(runtime_root)
    allow(described_class).to receive(:configure).and_yield(server)
    allow(server).to receive(:documentation_name=)
  end

  def write_settings(value = settings)
    File.write(File.join(runtime_root, 'config', 'documentation-oauth.json'), JSON.generate(value))
  end

  def write_key
    File.binwrite(File.join(runtime_root, 'config', 'documentation-session.key'), session_key)
  end

  def load_hook
    load File.expand_path('../../../../configs/vpsadmin/api/api.rb', __dir__)
  end

  def expect_sanitized_failure
    expect { load_hook }.to raise_error(ArgumentError, 'Invalid documentation OAuth configuration') do |error|
      expect(error.cause).to be_nil
      expect(error.full_message).not_to include(settings.fetch('client_secret'))
    end
    expect(server.extensions).to eq([mailer])
  end

  it 'keeps anonymous documentation and ExceptionMailer when private JSON is absent' do
    load_hook

    expect(server).not_to have_received(:documentation_oauth)
    expect(server).to have_received(:documentation_name=).with('api.example.test')
    expect(server.extensions).to eq([mailer])
    expect(HaveAPI::Extensions::ExceptionMailer).to have_received(:new).with(
      from: 'vpsadmin@vpsadmin.vpsfree.cz', to: 'aither@havefun.cz',
      subject: '[vpsAdmin API Error] %s', smtp: {}
    )
  end

  it 'reads the service runtime config rather than files adjacent to the store hook' do
    write_settings
    write_key
    load_hook

    expect(server).to have_received(:documentation_oauth).with(
      client_id: settings.fetch('client_id'), client_secret: settings.fetch('client_secret'),
      redirect_uri: settings.fetch('redirect_uri'), session_secret: session_key,
      scope: ['all'], session_lifetime: 3600, switch_user: false
    )

    expect(server.extensions).to eq([mailer])
  end

  it 'passes the explicitly enabled account switch option to the consumer' do
    write_settings(settings.merge('switch_user' => true))
    write_key
    load_hook

    expect(server).to have_received(:documentation_oauth).with(hash_including(switch_user: true))
  end

  it 'sanitizes malformed JSON without preserving a secret-bearing cause' do
    File.write(File.join(runtime_root, 'config', 'documentation-oauth.json'),
               '{"client_secret":"synthetic-private-value",invalid}')

    expect_sanitized_failure
  end

  it 'rejects non-object JSON' do
    write_settings([])

    expect_sanitized_failure
  end

  it 'rejects missing required fields' do
    write_settings(settings.except('client_id'))

    expect_sanitized_failure
  end

  it 'sanitizes a missing session-key file' do
    write_settings

    expect_sanitized_failure
  end

  it 'sanitizes consumer validation failures for invalid fields, keys or options' do
    write_settings(settings.merge('switch_user' => 'invalid'))
    write_key
    allow(server).to receive(:documentation_oauth).and_raise(ArgumentError, settings.fetch('client_secret'))

    expect_sanitized_failure
  end
end
