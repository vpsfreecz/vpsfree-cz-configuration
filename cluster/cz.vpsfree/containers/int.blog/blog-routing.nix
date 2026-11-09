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
      "= /_deploy/blog" = lib.mkIf (!cfg.publication.enable || host != "blog.vpsfree.cz") {
        return = "404";
      };
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
  config = {
    assertions = [
      {
        assertion = config.networking.firewall.enable;
        message = "The blog frontend requires the firewall to protect proxy-header trust.";
      }
      {
        assertion = !config.networking.nftables.enable && config.networking.firewall.backend == "iptables";
        message = "The blog frontend requires the reviewed iptables firewall backend.";
      }
      {
        assertion =
          builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+" proxy.addresses.primary.address != null;
        message = "The blog frontend requires an IPv4 primary address for the prg proxy metadata.";
      }
      {
        assertion =
          !(broadlyAllowed 80 config.networking.firewall)
          && !(lib.any (broadlyAllowed 80) (lib.attrValues config.networking.firewall.interfaces));
        message = "Blog TCP/80 must not be opened broadly; only the exact proxy IPv4 rule is allowed.";
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
              3306
            ];
        message = "Private and retired blog ports 8080, 8081, 8091 and 3306 must never be opened broadly.";
      }
    ];
    networking.nftables.enable = false;
    networking.firewall = {
      enable = true;
      backend = "iptables";
      extraCommands = ''
        # Accept backend HTTP only from the production proxy's exact IPv4.
        iptables -w -A nixos-fw -p tcp \
          -s ${proxy.addresses.primary.address}/32 --dport 80 \
          -j nixos-fw-accept
      '';
      # Firewall reload runs the new configuration's stop commands. Retire only
      # the two old WordPress SMTP hooks/chains, including on repeated reloads.
      extraStopCommands = ''
        while iptables -w -D OUTPUT -j vpsf-blog-smtp4 2>/dev/null; do :; done
        iptables -w -F vpsf-blog-smtp4 2>/dev/null || true
        iptables -w -X vpsf-blog-smtp4 2>/dev/null || true
        while ip6tables -w -D OUTPUT -j vpsf-blog-smtp6 2>/dev/null; do :; done
        ip6tables -w -F vpsf-blog-smtp6 2>/dev/null || true
        ip6tables -w -X vpsf-blog-smtp6 2>/dev/null || true
      '';
    };
    services.nginx.enable = true;
    services.nginx.enableReload = true;
    services.nginx.virtualHosts = {
      blog-front-cs = (frontend "blog.vpsfree.cz") // {
        locations = (frontend "blog.vpsfree.cz").locations // {
          "/" = if cfg.enable then forward 8080 "blog.vpsfree.cz" else { return = "503"; };
        };
      };
      blog-front-en = (frontend "blog.vpsfree.org") // {
        locations = (frontend "blog.vpsfree.org").locations // {
          "/" = if cfg.enable then forward 8080 "blog.vpsfree.org" else { return = "503"; };
        };
      };
      blog-front-unknown-host = {
        serverName = "_";
        default = true;
        listen = listen 80 "0.0.0.0";
        locations."/".return = "444";
      };
    };
  };
}
