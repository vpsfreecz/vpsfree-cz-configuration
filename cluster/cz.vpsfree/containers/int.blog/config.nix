{ ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ./wordpress.nix
    ./recovery-export.nix
  ];

  vpsfree.blog = {
    mode = "production";
    enableProductionCron = true;
    recovery = {
      enableAcceptedTimer = true;
      firstExpectedDate = "2026-07-22";
    };
  };

  system.stateVersion = "26.05";
}
