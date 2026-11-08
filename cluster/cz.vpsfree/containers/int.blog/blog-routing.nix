{
  config,
  lib,
  confLib,
  ...
}:
let
  cfg = config.services.vpsfree-static-blog;
  proxy = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
  listen = port: addr: [ { inherit addr port; } ];
  forward = port: host: {
    proxyPass = "http://127.0.0.1:${toString port}";
    recommendedProxySettings = false;
    extraConfig = ''
      proxy_set_header Host ${host};
      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-Proto https;
    '';
  };
  frontend = host: {
    serverName = host;
    listen = listen 80 "0.0.0.0";
    extraConfig = ''
      set_real_ip_from ${proxy.addresses.primary.address}/32;
      real_ip_header X-Real-IP;
      real_ip_recursive off;
    '';
    locations = {
      "= /_deploy/blog".return = "404";
      "^~ /_deploy/".return = "404";
      "^~ /_hooks/".return = "404";
    };
  };
  broadlyAllowed =
    port: firewall:
    lib.elem port firewall.allowedTCPPorts
    || lib.any (range: range.from <= port && port <= range.to) firewall.allowedTCPPortRanges;
in
{
  options.services.vpsfree-static-blog.serveStatic = lib.mkEnableOption "static content on the backend blog frontend";

  config = {
    assertions = [
      {
        assertion = !cfg.serveStatic || cfg.enable;
        message = "Backend static blog routing requires services.vpsfree-static-blog.enable.";
      }
      {
        assertion =
          lib.all
            (
              port:
              !(broadlyAllowed port config.networking.firewall)
              && !(lib.any (broadlyAllowed port) (lib.attrValues config.networking.firewall.interfaces))
            )
            [
              8080
              8081
              8091
            ];
        message = "Internal blog ports 8080, 8081 and 8091 must never be opened broadly.";
      }
    ];
    services.nginx.virtualHosts = {
      blog-front-cs = (frontend "blog.vpsfree.cz") // {
        locations = (frontend "blog.vpsfree.cz").locations // {
          "/" = forward (if cfg.serveStatic then 8080 else 8081) "blog.vpsfree.cz";
        };
      };
      blog-front-en = (frontend "blog.vpsfree.org") // {
        locations = (frontend "blog.vpsfree.org").locations // {
          "/" = if cfg.serveStatic then forward 8080 "blog.vpsfree.org" else { return = "503"; };
        };
      };
      blog-front-unknown-host = {
        serverName = "_";
        default = true;
        listen = listen 80 "0.0.0.0";
        locations."/".return = "444";
      };
      blog-wordpress-unknown-host = {
        serverName = "_";
        default = true;
        listen = listen 8081 "127.0.0.1";
        locations."/".return = "444";
      };
    };
  };
}
