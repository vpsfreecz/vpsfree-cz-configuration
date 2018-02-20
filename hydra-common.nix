{
  i18n.defaultLocale = "en_US.UTF-8";

  services.nixosManual.showManual = false;
  services.ntp.enable = false;
  services.openssh.allowSFTP = false;
  services.openssh.passwordAuthentication = false;

  nix.nrBuildUsers = 100;
  nix.buildCores = 0;
  systemd.tmpfiles.rules = [ "d /tmp 1777 root root 7d" ];

  users = {
    mutableUsers = false;
    users.root.openssh.authorizedKeys.keyFiles = [ ~/.ssh/id_rsa.pub ];
  };

}
