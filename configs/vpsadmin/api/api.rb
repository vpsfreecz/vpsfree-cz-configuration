require 'json'
require 'uri'

VpsAdmin::API.configure do |server|
  server.extensions << HaveAPI::Extensions::ExceptionMailer.new(
    from: 'vpsadmin@vpsadmin.vpsfree.cz',
    to: 'aither@havefun.cz',
    subject: '[vpsAdmin API Error] %s',
    smtp: {}
  )

  server.documentation_name = URI.parse(SysConfig.get(:core, :api_url)).host

  config_path = File.join(VpsAdmin::API.root, 'config', 'documentation-oauth.json')
  next unless File.exist?(config_path)

  begin
    settings = JSON.parse(File.read(config_path))
    raise ArgumentError unless settings.is_a?(Hash)

    server.documentation_oauth(
      client_id: settings.fetch('client_id'),
      client_secret: settings.fetch('client_secret'),
      redirect_uri: settings.fetch('redirect_uri'),
      session_secret: File.binread(File.join(VpsAdmin::API.root, 'config', 'documentation-session.key')),
      scope: ['all'],
      session_lifetime: 3600,
      switch_user: settings.fetch('switch_user', false)
    )
  rescue JSON::ParserError, KeyError, ArgumentError, TypeError, SystemCallError
    raise ArgumentError, 'Invalid documentation OAuth configuration', cause: nil
  end
end
