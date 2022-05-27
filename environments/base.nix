{ config, pkgs, lib, confData, confMachine, swpins, ... }:
with lib;
{
  time.timeZone = "Europe/Amsterdam";

  networking = {
    search = ["vpsfree.cz" "prg.vpsfree.cz" "base48.cz"];
    nameservers = [ "172.16.9.90" "1.1.1.1" ];
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
