# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'

require_relative '../../../lib/vpsadmin_config/event_i18n/catalog'

RSpec.describe VpsAdminConfig::EventI18n::Catalog do
  let(:root) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(root)
  end

  def catalog
    described_class.new(root:)
  end

  def monitoring_path
    File.join(root, described_class::MONITORING_PATH)
  end

  def locale_path(locale)
    File.join(root, described_class::LOCALE_DIR, "#{locale}.yml")
  end

  def write_monitoring(content)
    FileUtils.mkdir_p(File.dirname(monitoring_path))
    File.write(monitoring_path, content)
  end

  def write_locale(locale, labels)
    data = {
      locale => {
        'vpsadmin' => {
          'events' => {
            'types' => labels.transform_values { |label| { 'label' => label } }
          }
        }
      }
    }
    FileUtils.mkdir_p(File.dirname(locale_path(locale)))
    File.write(locale_path(locale), described_class::HEADER + YAML.dump(data))
  end

  def write_valid_locales
    write_locale('en', 'monitoring_spec_alert' => 'Spec alert')
    write_locale('cs', 'monitoring_spec_alert' => 'Spec alert česky')
  end

  it 'generates English labels and Czech placeholders' do
    write_monitoring(<<~RUBY)
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event 'monitoring.spec_alert',
                    label: 'Spec alert',
                    template: :alert_spec
      end
    RUBY

    catalog.update!

    en = YAML.load_file(locale_path('en'))
    cs = YAML.load_file(locale_path('cs'))
    expect(en.dig('en', 'vpsadmin', 'events', 'types', 'monitoring_spec_alert', 'label')).to eq('Spec alert')
    expect(cs.dig('cs', 'vpsadmin', 'events', 'types', 'monitoring_spec_alert', 'label')).to eq('TODO')
  end

  it 'passes health when labels are translated and normalized' do
    write_monitoring(<<~RUBY)
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event 'monitoring.spec_alert',
                    label: 'Spec alert',
                    template: :alert_spec
      end
    RUBY
    write_valid_locales

    expect(catalog.check!).to be(true)
  end

  it 'fails health when a Czech label is missing' do
    write_monitoring(<<~RUBY)
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event 'monitoring.spec_alert',
                    label: 'Spec alert',
                    template: :alert_spec
      end
    RUBY
    write_locale('en', 'monitoring_spec_alert' => 'Spec alert')
    write_locale('cs', {})

    expect { catalog.check! }.to raise_error(/missing vpsadmin\.events\.types\.monitoring_spec_alert\.label/)
  end

  it 'fails health when a Czech label is still TODO' do
    write_monitoring(<<~RUBY)
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event 'monitoring.spec_alert',
                    label: 'Spec alert',
                    template: :alert_spec
      end
    RUBY
    write_locale('en', 'monitoring_spec_alert' => 'Spec alert')
    write_locale('cs', 'monitoring_spec_alert' => 'TODO')

    expect { catalog.check! }.to raise_error(/missing translation for vpsadmin\.events\.types\.monitoring_spec_alert\.label/)
  end

  it 'fails health when a stale label remains' do
    write_monitoring(<<~RUBY)
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event 'monitoring.spec_alert',
                    label: 'Spec alert',
                    template: :alert_spec
      end
    RUBY
    write_locale('en', 'monitoring_spec_alert' => 'Spec alert')
    write_locale(
      'cs',
      'monitoring_spec_alert' => 'Spec alert česky',
      'monitoring_old_alert' => 'Stará událost'
    )

    expect { catalog.check! }.to raise_error(/unused vpsadmin\.events\.types\.monitoring_old_alert/)
  end

  it 'fails health when event names are duplicated' do
    write_monitoring(<<~RUBY)
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event 'monitoring.spec_alert',
                    label: 'Spec alert',
                    template: :alert_spec
        alert_event 'monitoring.spec_alert',
                    label: 'Spec alert again',
                    template: :alert_spec_again
      end
    RUBY
    write_valid_locales

    expect { catalog.check! }.to raise_error(/duplicate alert_event "monitoring\.spec_alert"/)
  end

  it 'fails health when event names are dynamic' do
    write_monitoring(<<~RUBY)
      event_name = 'monitoring.spec_alert'
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event event_name,
                    label: 'Spec alert',
                    template: :alert_spec
      end
    RUBY
    write_valid_locales

    expect { catalog.check! }.to raise_error(/alert_event on line .* plain string literal/)
  end

  it 'fails health when labels are dynamic' do
    write_monitoring(<<~RUBY)
      label = 'Spec alert'
      VpsAdmin::API::Plugins::Monitoring.config do
        alert_event 'monitoring.spec_alert',
                    label: label,
                    template: :alert_spec
      end
    RUBY
    write_valid_locales

    expect { catalog.check! }.to raise_error(/label for alert_event "monitoring\.spec_alert" must use a plain string literal/)
  end
end
