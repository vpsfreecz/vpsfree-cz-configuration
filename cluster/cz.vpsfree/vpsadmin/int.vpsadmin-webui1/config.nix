{
  config,
  pkgs,
  confLib,
  confMachine,
  flakeInputs,
  inputsInfo,
  ...
}:
let
  webuiInput = flakeInputs.${inputsInfo."vpsadmin-webui".input};
  packages = webuiInput.packages.${pkgs.stdenv.hostPlatform.system};
  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
  proxyAddress = proxyPrg.addresses.primary.address;
  privateAddress = confMachine.addresses.primary.address;
in
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    webuiInput.nixosModules.default
  ];

  system.stateVersion = "26.05";

  environment.systemPackages = [ pkgs.jq ];

  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -p tcp --dport 80 -s ${proxyAddress}/32 -j nixos-fw-accept
    iptables -A nixos-fw -p tcp --dport 80 -s ${privateAddress}/32 -j nixos-fw-accept
  '';

  services."vpsadmin-webui" = {
    enable = true;
    frontendPackage = packages.frontend;
    bffPackage = packages.bff;
    publicOrigin = "https://newadmin.vpsfree.cz";
    api = {
      url = "https://api.vpsfree.cz";
      version = "7.0";
    };
    oauth = {
      authorizeUrl = "https://auth.vpsfree.cz/_auth/oauth2/authorize";
      tokenUrl = "https://auth.vpsfree.cz/_auth/oauth2/token";
      revokeUrl = "https://auth.vpsfree.cz/_auth/oauth2/revoke";
      passwordRecoveryUrl = "https://auth.vpsfree.cz/oauth2/password-reset";
      scope = "all";
      type = "web_server";
    };
    legacyWebuiUrl = "https://vpsadmin.vpsfree.cz";
    haveApi = {
      authHeader = "X-HaveAPI-OAuth2-Token";
      metaNamespace = "_meta";
    };
    credentialFiles = {
      oauthClientId = "/private/vpsadmin-webui/oauth-client-id";
      oauthClientSecret = "/private/vpsadmin-webui/oauth-client-secret";
      sessionSecret = "/private/vpsadmin-webui/session-secret";
    };
    cookieName = "vpsadmin_webui_session";
    bffPort = 3001;
    nginx = {
      enable = true;
      listenAddress = privateAddress;
      port = 80;
      trustedProxyAddresses = [ "${proxyAddress}/32" ];
      allowedClientAddresses = [
        "${proxyAddress}/32"
        "${privateAddress}/32"
        "127.0.0.1/32"
      ];
    };
    # The console router and public heatmap setting are iframe targets; the
    # parent UI does not connect directly to the console origin.
    security.consoleOrigins = [ ];
    security.frameOrigins = [
      "https://console.vpsfree.cz"
      "https://goresheat.vpsfree.cz"
    ];
  };
}
