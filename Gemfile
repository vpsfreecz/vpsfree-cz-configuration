source 'https://rubygems.org'

confctl_path = ENV.fetch('CONFCTL_SRC', nil)

if confctl_path && !confctl_path.empty?
  gem 'confctl', path: confctl_path
else
  gem 'confctl'
end

group :development do
  gem 'overcommit'
  gem 'rubocop', '~> 1.75.0'
  gem 'rubocop-rake'
end
