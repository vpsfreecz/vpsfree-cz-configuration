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
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>goresheat: live system usage monitor</title>
        <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet" integrity="sha384-QWTKZyjpPEjISv5WaRU9OFeRpok6YctnYmDr5pNlyT2bRjXh0JMhjY6hW+ALEwIH" crossorigin="anonymous">
      </head>
      <body>
        <h1>goresheat: live system usage monitor</h1>
        <ul>
          ${concatMapStringsSep "\n" (m: ''<li><a href="/${m.metaConfig.host.fqdn}/">${m.metaConfig.host.fqdn}</a></li>'') allNodes}
        </ul>
        <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js" integrity="sha384-YvpcrYf0tY3lHB60NNkmXc5s9fDVZLESaAA55NDzOxhy9GkcIdslK1eN7N6jIeHz" crossorigin="anonymous"></script>
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
