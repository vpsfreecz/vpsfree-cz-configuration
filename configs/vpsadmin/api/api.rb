api do |server|
  server.extensions << HaveAPI::Extensions::ExceptionMailer.new(
    from: 'vpsadmin@vpsadmin.vpsfree.cz',
    to: 'aither@havefun.cz',
    subject: '[vpsAdmin API Error] %s',
    smtp: {},
  )
end
