{
  config,
  confLib,
  confMachine,
  ...
}:
let
  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };

  geminaboxPort = confMachine.services.geminabox.port;
in
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access to geminabox from proxy.prg
    iptables -A nixos-fw -p tcp --dport ${toString geminaboxPort} -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  services.geminabox = {
    enable = true;
    address = "0.0.0.0";
    port = geminaboxPort;

    settings = {
      allow_upload = false;
      allow_replace = false;
      allow_delete = false;
    };

    pushBasicAuth = {
      enable = true;
      users = {
        aither = "/private/geminabox/aither.pw";
        aitherdev = "/private/geminabox/aitherdev.pw";
      };
    };

    garbage-collector.enable = false;
  };

  system.stateVersion = "22.05";
}
