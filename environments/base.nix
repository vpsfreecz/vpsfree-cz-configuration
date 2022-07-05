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

  internalDnsAddresses = map (m: m.addresses.primary.address) [ ns1IntPrg ns1IntBrq ];
in {
  time.timeZone = "Europe/Amsterdam";

  networking = {
    search = ["vpsfree.cz" "prg.vpsfree.cz" "base48.cz"];
    nameservers = internalDnsAddresses ++ [ "1.1.1.1" ];
  };

  services.openssh.enable = true;

  nixpkgs.overlays = import ../overlays;

  nix.useSandbox = true;

  nix.nixPath = [
    "nixpkgs=${swpins.nixpkgs}"
  ] ++ (optional (hasAttr "vpsadminos" swpins) "vpsadminos=${swpins.vpsadminos}");

  environment.systemPackages = with pkgs; [
    wget
    vim
    screen
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

  users.users.root.openssh.authorizedKeys.keys = with confData.sshKeys; admins ++ builders;
}
