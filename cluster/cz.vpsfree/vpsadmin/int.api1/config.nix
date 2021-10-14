{ pkgs, lib, config, ... }:
{
  imports = [
    ../common/all.nix
    ../common/api.nix
  ];

  vpsadmin.api = {
    # scheduler.enable = true;

    # rake.enableDefaultTasks = true;
    # rake.tasks.payments-process.timer.enable = lib.mkForce false;
    # rake.tasks.requests-ipqs.timer.enable = lib.mkForce false;
  };
}
