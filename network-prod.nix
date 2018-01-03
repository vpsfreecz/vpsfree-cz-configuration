{
  network.description = "vpsFree infrastructure";

  netboot =
    { config, lib, pkgs, ...}:
    {
      imports = [
        ../build-vpsfree-templates/files/configuration.nix
      ];

      deployment.targetHost = "172.17.4.99";
    };
  hydra =
    { config, lib, pkgs, ... }:
    {

      deployment.targetHost = "172.16.0.7";
      boot.loader.grub.device = "/dev/sda";
      fileSystems."/" =
        { device = "/dev/disk/by-uuid/d6e9b823-a6da-43b1-b938-a07bc239437f";
          fsType = "ext4";
        };
      swapDevices =
        [ { device = "/dev/disk/by-uuid/3a617558-c265-46e6-85c4-3964b802ef24"; }
        ];

      networking.interfaces.ens3.ip4 = [ { address = "172.16.0.7"; prefixLength = 23; } ];
      networking.defaultGateway = "172.16.0.1";

      programs.ssh.extraConfig = lib.mkAfter
        ''
          ServerAliveInterval 120
          TCPKeepAlive yes
          Host hydra_slave
          Hostname 172.16.0.250
          Compression yes
        '';
      services.openssh.knownHosts =
        [
          { hostNames = [ "172.16.0.250" ]; publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGr0uNEjmLVw1asYwLIR0nkveuA3zFkY3u3ywRjFcowQ"; }
        ];
    };
  hydra_slave =
    { config, lib, pkgs, ... }:
    {
      deployment.targetHost = "172.16.0.250";
      boot.loader.grub.device = "/dev/sda";
      networking.interfaces.ens3.ip4 = [ { address = "172.16.0.250"; prefixLength = 23; } ];
      networking.defaultGateway = "172.16.0.1";
      fileSystems."/" =
        { device = "/dev/disk/by-uuid/b9bb3920-23bb-49d6-bbe4-cfbc65135858";
          fsType = "ext4";
        };
    };
}
