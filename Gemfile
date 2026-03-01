source 'https://rubygems.org'

confctl_path = ENV.fetch('CONFCTL_SRC', nil)

if confctl_path.nil? || confctl_path.empty?
  raise 'CONFCTL_SRC must be set (use nix develop)'
end

gem 'confctl', path: confctl_path

group :development do
  gem 'overcommit'
  gem 'rubocop', '~> 1.75.0'
  gem 'rubocop-rake'
end
