{ config, pkgs, ... }:
{
  imports = [
    ./blog.vpsfree.cz.nix
    ./foto.vpsfree.cz.nix
  ];

  networking.firewall.extraCommands = ''
    # Allow access from proxy
    iptables -A nixos-fw -p tcp --dport 80 -s 37.205.9.80 -j nixos-fw-accept
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