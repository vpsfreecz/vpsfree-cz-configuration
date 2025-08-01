{
  config,
  pkgs,
  confLib,
  ...
}:
let
  proxyPrg = confLib.findMetaConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/proxy";
  };
in
{
  imports = [
    ./blog.vpsfree.cz.nix
    ./foto.vpsfree.cz.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access from proxy
    iptables -A nixos-fw -p tcp --dport 80 -s ${proxyPrg.addresses.primary.address} -j nixos-fw-accept
  '';

  environment.systemPackages = with pkgs; [
    git
    php.packages.composer
  ];

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
  };

  services.vpsfree-web = {
    enable = true;
    virtualHosts = {
      "vpsfree.cz".language = "cs";

      "vpsfree.org".language = "en";

      "web-dev.vpsfree.cz" = {
        web = "/var/www/dev.vpsfree.cz";
        language = "cs";
      };

      "web-dev.vpsfree.org" = {
        web = "/var/www/dev.vpsfree.cz";
        language = "en";
      };
    };
  };
}
