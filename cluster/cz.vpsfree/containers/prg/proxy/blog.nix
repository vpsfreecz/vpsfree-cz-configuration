{
  config,
  confLib,
  ...
}:
let
  blog = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/int.blog";
  };
  vhost = host: {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://${blog.addresses.primary.address}:80";
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host ${host};
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
in
{
  config.services.nginx.virtualHosts = {
    "blog.vpsfree.cz" = (vhost "blog.vpsfree.cz") // {
      locations = (vhost "blog.vpsfree.cz").locations // {
        "= /_deploy/blog" = {
          proxyPass = "http://${blog.addresses.primary.address}:80";
          recommendedProxySettings = false;
          extraConfig = ''
            client_max_body_size 512m;
            client_body_timeout 180s;
            proxy_connect_timeout 5s;
            proxy_read_timeout 180s;
            proxy_send_timeout 180s;
            proxy_request_buffering on;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host blog.vpsfree.cz;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-Proto $scheme;
            access_log off;
            error_log /dev/null;
          '';
        };
      };
    };
    "blog.vpsfree.org" = vhost "blog.vpsfree.org";
  };
}
