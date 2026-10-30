{
  httpConfig = ''
    log_format oauth_client '$remote_addr [$time_local] "$request_method $uri $server_protocol" $status $body_bytes_sent $request_time $upstream_response_time $upstream_status';
  '';

  serverConfig = ''
    access_log /var/log/nginx/oauth-clients.log oauth_client;
    error_log /dev/null crit;
  '';

  referrerConfig = ''
    proxy_hide_header Referrer-Policy;
    fastcgi_hide_header Referrer-Policy;
    add_header Referrer-Policy strict-origin always;
  '';
}
