{
  config,
  pkgs,
  lib,
  inputs ? { },
  ...
}:
let
  inherit (lib)
    any
    attrValues
    mapAttrs
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.services.vpsfree-web;

  source = if inputs ? vpsfreeWeb then inputs.vpsfreeWeb else null;

  configFile = pkgs.writeText "vpsfree-config.php" ''
    <?php
    define ('API_URL', 'https://api.vpsfree.cz');
    define ('ENVIRONMENT_ID', 1);
  '';

  configured =
    if source == null then
      null
    else
      pkgs.runCommand "vpsfree-web" { } ''
        mkdir $out
        cp -r ${source}/. $out/

        # NOTE: ln doesn't work properly, possibly due to composer2nix. The dependency
        # is not tracked by Nix and configFile is not copied to the target system.
        cp ${configFile} $out/config.php
      '';

  needsDefaultWeb = any (vhostCfg: vhostCfg.web == null) (attrValues cfg.virtualHosts);

  defaultWeb =
    if !needsDefaultWeb then
      null
    else if configured == null then
      throw "services.vpsfree-web requires the vpsfreeWeb input; enable the vpsfree-web channel on this machine"
    else
      import configured { inherit pkgs; };

  vhost =
    {
      domain,
      web,
      language,
    }:
    {
      serverAliases = [ "www.${domain}" ];
      enableACME = false;
      forceSSL = false;
      root = "${web}/${language}/";
      locations."~ \.php$".extraConfig = ''
        ssi on;
        gzip off;
        fastcgi_pass  unix:${config.services.phpfpm.pools.vpsfree.socket};
      '';
      locations."/".extraConfig = ''
        gzip off;
        ssi on;
      '';
      locations."/prihlaska/".extraConfig = ''
        gzip off;
        ssi on;
      '';
      locations."/css/".extraConfig = ''
        alias ${web}/css/;
      '';
      locations."/js/".extraConfig = ''
        alias ${web}/js/;
      '';
      locations."/obrazky/".extraConfig = ''
        alias ${web}/obrazky/;
      '';
      locations."/download/".extraConfig = ''
        alias ${web}/download/;
      '';
    };

  virtualHostModule = {
    options = {
      web = mkOption {
        type = types.nullOr types.path;
        default = null;
      };

      language = mkOption {
        type = types.enum [
          "cs"
          "en"
        ];
      };
    };
  };
in
{
  options = {
    services.vpsfree-web = {
      enable = mkEnableOption "vpsFree.cz web presentation";

      virtualHosts = mkOption {
        type = types.attrsOf (types.submodule virtualHostModule);
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      xz # For Slovak QR Payments
    ];

    services.nginx = {
      enable = true;

      virtualHosts = mapAttrs (
        name: vhostCfg:
        vhost {
          domain = name;
          web = if vhostCfg.web != null then vhostCfg.web else defaultWeb;
          inherit (vhostCfg) language;
        }
      ) cfg.virtualHosts;
    };

    services.phpfpm.pools.vpsfree = {
      user = "vpsfree";
      group = "vpsfree";

      settings = {
        "pm" = "dynamic";
        "listen.owner" = config.services.nginx.user;
        "pm.max_children" = 5;
        "pm.start_servers" = 2;
        "pm.min_spare_servers" = 1;
        "pm.max_spare_servers" = 3;
        "pm.max_requests" = 500;
      };
    };

    users = {
      users.vpsfree = {
        isSystemUser = true;
        group = "vpsfree";
        description = "vpsfree main web account";
      };

      groups.vpsfree = { };
    };
  };
}
