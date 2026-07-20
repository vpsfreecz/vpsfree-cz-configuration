{ ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    ./wordpress.nix
    ./recovery-export.nix
  ];

  # Initial deployment is a disposable rehearsal generation. Production cron
  # and the accepted pre-snapshot export remain separate reviewed transitions.
  vpsfree.blog = {
    mode = "rehearsal";
    enableProductionCron = false;
    recovery.enableAcceptedTimer = false;
  };

  system.stateVersion = "26.05";
}
