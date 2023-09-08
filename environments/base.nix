{ config, pkgs, lib, confLib, confData, confMachine, swpins, ... }:
with lib;
let
  ns1IntPrg = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/prg/int.ns1";
  };

  ns1IntBrq = confLib.findConfig {
    cluster = config.cluster;
    name = "cz.vpsfree/containers/brq/int.ns1";
  };

  defaultInternalDns = [ ns1IntPrg ns1IntBrq ];

  internalDns =
    if isNull confMachine then
      defaultInternalDns
    else if confMachine.host.location == "brq" then
      [ ns1IntBrq ns1IntPrg ]
    else
      defaultInternalDns;

  internalDnsAddresses = map (m: m.addresses.primary.address) internalDns;

  adminSshKeys = flatten (mapAttrsToList (k: v: v.authorizedKeys) config.vpsfconf.admins);
in {
  # NOTE: Whenever adding new settings to this file, remember that it is used for
  # everything in this configuration, including netboot images for pure NixOS
  # used as a rescue system. Those images must be made to import any
  # vpsfconf-specific modules, as they're minimal by default, see ../lib/images.nix.

  imports = [
    ../configs/admins.nix
  ];

  time.timeZone = "Europe/Amsterdam";

  networking = {
    search = ["vpsfree.cz" "prg.vpsfree.cz" "base48.cz"];
    nameservers = internalDnsAddresses ++ [ "1.1.1.1" ];
  };

  services.openssh.enable = true;

  nixpkgs.overlays = import ../overlays;

  nix.settings.sandbox = true;

  nix.nixPath = [
    "nixpkgs=${swpins.nixpkgs}"
  ] ++ (optional (hasAttr "vpsadminos" swpins) "vpsadminos=${swpins.vpsadminos}");

  environment.systemPackages = with pkgs; [
    wget
    vim
    screen
    config.boot.kernelPackages.perf
  ];

  programs.bash.promptInit =
    let
      hostname = if confMachine == null then "\\H" else confMachine.host.fqdn;
    in ''
      # Provide a nice prompt if the terminal supports it.
      if [ "$TERM" != "dumb" -o -n "$INSIDE_EMACS" ]; then
        PS1="[\[\e[1;31m\]\u\[\e[0;00m\]@\[\e[1;31m\]${hostname}\[\e[0;00m\]]\n \w \[\e[1;31m\]# \[\e[0;00m\]"
      fi
    '';

  programs.bepastyrb.enable = true;

  users.users.root.openssh.authorizedKeys.keys = adminSshKeys ++ confData.sshKeys.builders;
}
