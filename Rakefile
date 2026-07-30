# frozen_string_literal: true

require 'bundler/setup'
require 'rspec/core/rake_task'

$:.unshift(File.expand_path('lib', __dir__))

RSpec::Core::RakeTask.new(:spec)

namespace :vpsadmin do
  namespace :events do
    namespace :i18n do
      desc 'Generate vpsAdmin event translation catalogs'
      task :update do
        require 'vpsadmin_config/event_i18n/catalog'

        VpsAdminConfig::EventI18n::Catalog.new(root: __dir__).update!
      end

      desc 'Check vpsAdmin event translation coverage'
      task :health do
        require 'vpsadmin_config/event_i18n/catalog'

        VpsAdminConfig::EventI18n::Catalog.new(root: __dir__).check!
      end
    end
  end
end

task default: :spec
