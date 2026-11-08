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
    "blog.vpsfree.cz" = vhost "blog.vpsfree.cz";
    "blog.vpsfree.org" = vhost "blog.vpsfree.org";
  };
}
