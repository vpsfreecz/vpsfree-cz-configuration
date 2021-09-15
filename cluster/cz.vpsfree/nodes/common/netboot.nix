{ config, lib, pkgs, ...}:
{
  boot.initrd.kernelModules = [
    "igb" "ixgbe" "tg3"
  ];

  environment.etc =
    let
      prefix = "/secrets/nodes/${ config.networking.hostName }/ssh";
      path = pkgs.copyPathToStore prefix;
    in {
      "ssh/ssh_host_rsa_key.pub".source = "${ path }/ssh_host_rsa_key.pub";
      "ssh/ssh_host_rsa_key" = { mode = "0600"; source = "${ path }/ssh_host_rsa_key"; };
      "ssh/ssh_host_ed25519_key.pub".source = "${ path }/ssh_host_ed25519_key.pub";
      "ssh/ssh_host_ed25519_key" = { mode = "0600"; source = "${ path }/ssh_host_ed25519_key"; };
    };
}
