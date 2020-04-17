{ config, pkgs, lib, ...}:
{
  imports = [
    ./hardware.nix
    ../common.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.version = 2;
  boot.loader.grub.mirroredBoots = [
    { path = "/boot1"; devices = [ "/dev/disk/by-id/wwn-0x6848f690ea7f3200262b9f0d124ba2eb" ]; }
    { path = "/boot2"; devices = [ "/dev/disk/by-id/wwn-0x6848f690ea7f3200262b9f4d161b4c95" ]; }
  ];

  networking.hosts = {"1.2.3.4" = ["exampleee.com"];};

  boot.zfs.pools.rpool = {};

  boot.kernelParams = [ "nolive" ];

  # Temporarily disable tc which is used to configure shaper
  runit.services.nodectld.run =
    let
      bindir = pkgs.runCommand "bindir" {} ''
        mkdir -p $out/bin
        cat <<EOF > $out/bin/tc
        #!/bin/sh
        exit 0
        EOF
        chmod +x $out/bin/tc
      '';
    in lib.mkForce ''
      ulimit -c unlimited
      export PATH="${bindir}/bin:$PATH"
      export HOME=${config.users.extraUsers.root.home}
      exec 2>&1
      exec ${pkgs.nodectld}/bin/nodectld --log syslog --log-facility local3 --export-console
    '';
}
