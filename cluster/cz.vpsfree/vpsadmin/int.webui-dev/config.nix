{ pkgs, lib, config, confData, ... }:
let
  devUser = "vpsadmin-dev";
in {
  imports = [
    ../common/all.nix
    ../common/webui.nix
  ];

  environment.systemPackages = with pkgs; [
    git
  ];

  users.users.${devUser} = {
    isNormalUser = true;
    createHome = false;
    openssh.authorizedKeys.keys = confData.sshKeys.admins;
  };

  vpsadmin.webui = {
    sourceCodeDir = "${config.users.users.${devUser}.home}/vpsadmin/webui";
    domain = "vpsadmin-dev.vpsfree.cz";
  };
}
