{ pkgs, confData, ... }:
{
  users.groups.log-readers = { };
  users.users.log-reader = {
    isNormalUser = true;
    group = "log-readers";
    home = "/home/log-reader";
    homeMode = "0700";
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ "restrict ${confData.sshKeys.aither.aitherdev}" ];
  };

  # A writable home must not let this shell account authorize less restricted keys.
  services.openssh.extraConfig = ''
    Match User log-reader
      AuthenticationMethods publickey
      PubkeyAuthentication yes
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      AuthorizedKeysFile /etc/ssh/authorized_keys.d/%u
      AuthorizedKeysCommand none
      AuthorizedPrincipalsFile none
      TrustedUserCAKeys none
      DisableForwarding yes
      AllowTcpForwarding no
      AllowStreamLocalForwarding no
      AllowAgentForwarding no
      X11Forwarding no
      PermitTTY no
      PermitTunnel no
      PermitUserRC no
    Match all
  '';

  # Historical permissions are deliberately operator-controlled, never activation.
  environment.systemPackages = [
    (pkgs.writeScriptBin "log-reader-reconcile" ''
      #!${pkgs.python3}/bin/python3
      ${builtins.readFile ./log-reader-reconcile.py}
    '')
  ];
}
