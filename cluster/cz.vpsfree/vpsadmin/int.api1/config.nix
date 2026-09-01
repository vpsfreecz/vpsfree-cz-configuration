{
  pkgs,
  lib,
  config,
  flakeInputs,
  inputsInfo,
  ...
}:
let
  notificationTemplatesInfo = inputsInfo."vpsfree-notification-templates";
  notificationTemplatesInput = notificationTemplatesInfo.input;
  notificationTemplatesPackage =
    flakeInputs.${notificationTemplatesInput}.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    ../common/all.nix
    ../common/api.nix
  ];

  vpsadmin.api = {
    scheduler.enable = true;

    notificationTemplates = {
      mode = "replace";
      source = notificationTemplatesPackage;
    };

    rake.enableDefaultTasks = true;
    # rake.tasks.payments-process.timer.enable = lib.mkForce false;
  };

  system.stateVersion = "22.05";
}
