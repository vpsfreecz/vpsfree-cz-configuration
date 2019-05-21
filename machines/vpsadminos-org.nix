{ config, pkgs, lib, ... }:
{
  imports = [
    ./netboot-server.nix
  ];
  netboot.host = "boot.vpsadminos.org";
  netboot.acmeSSL = true;
  web.acmeSSL = true;
}
