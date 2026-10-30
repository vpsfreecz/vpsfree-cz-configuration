{
  pkgs,
  lib,
  config,
  confLib,
  ...
}:
let
  oauthClientLogs = import ../../../../configs/nginx/oauth-client-logs.nix;

  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in
{
  vpsadmin.webui = {
    enable = true;

    productionEnvironmentId = 1;

    domain = lib.mkDefault "vpsadmin.vpsfree.cz";

    api = {
      externalUrl = "https://api.vpsfree.cz";
      internalUrl = "http://${proxyPrg.addresses.primary.address}:5000";
      oauth2TrustedOrigins = [ "https://auth.vpsfree.cz" ];
    };

    extraConfig = ''
      require "/private/vpsadmin-webui.php";
    '';

    softwareRevisionLinks.system_configuration = "https://github.com/vpsfreecz/vpsfree-cz-configuration/commit/";

    allowedIPv4Ranges = [
      "${proxyPrg.addresses.primary.address}/32"
    ];
  };

  services.phpfpm.pools.vpsadmin-webui.settings."php_admin_value[error_log]" = lib.mkForce "syslog";

  services.nginx = {
    commonHttpConfig = oauthClientLogs.httpConfig;
    virtualHosts.${config.vpsadmin.webui.domain}.extraConfig =
      oauthClientLogs.serverConfig + oauthClientLogs.referrerConfig;
  };
}
