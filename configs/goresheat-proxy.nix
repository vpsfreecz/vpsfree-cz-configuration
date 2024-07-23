{ config, pkgs, lib, confLib, ... }:
let
  inherit (lib) concatMapStringsSep filter listToAttrs mkMerge nameValuePair;

  allMachines = confLib.getClusterMachines config.cluster;

  allNodes = filter (m: m.metaConfig.node != null && m.metaConfig.monitoring.enable && isNull m.carrier) allMachines;

  upstreamName = node: "goresheat_${builtins.replaceStrings [ "." ] [ "_" ] node.metaConfig.host.fqdn}";

  mkUpstreams = listToAttrs (map (m: nameValuePair (upstreamName m) {
    servers = {
      "${m.metaConfig.addresses.primary.address}:${toString m.metaConfig.services.goresheat.port}" = {};
    };
  }) allNodes);

  mkGoresheatWebsockets = listToAttrs (map (m: nameValuePair "/${m.metaConfig.host.fqdn}/ws" {
    priority = 400;
    proxyPass = "http://${upstreamName m}/ws";
    extraConfig = ''
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
    '';
  }) allNodes);

  mkGoresheatRoots = listToAttrs (map (m: nameValuePair "/${m.metaConfig.host.fqdn}/" {
    priority = 500;
    proxyPass = "http://${upstreamName m}/";
  }) allNodes);

  indexFile = pkgs.writeText "goresheat-index.html" ''
    <!DOCTYPE html>
    <html>
      <head>
        <title>goresheat: live system usage monitor</title>
      </head>
      <body>
        <h1>goresheat: live system usage monitor</h1>
        <ul>
          ${concatMapStringsSep "\n" (m: ''<li><a href="/${m.metaConfig.host.fqdn}/">${m.metaConfig.host.fqdn}</a></li>'') allNodes}
        </ul>
      </body>
    </html>
  '';

  documentRoot = pkgs.runCommand "goresheat-root" {} ''
    mkdir $out
    ln -s ${indexFile} $out/index.html
  '';
in {
  services.nginx = {
    upstreams = mkUpstreams;

    virtualHosts."goresheat.vpsfree.cz" = {
      enableACME = true;
      forceSSL = true;
      locations = mkMerge [
        mkGoresheatRoots
        mkGoresheatWebsockets
        {
          "/" = {
            priority = 1000;
            root = documentRoot;
          };
        }
      ];
    };
  };
}
