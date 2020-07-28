{ config, pkgs, lib, ...}:
{
  imports = [
    ../common.nix
    ../../common/netboot.nix
    ../../common/tank.nix
  ];

  boot.zfs.pools = {
    tank = {
      install = true;
      wipe = [ "sda" "sdb" "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ];
      layout = [
        { type = "raidz"; devices = [ "nvme0n1" "nvme1n1" "nvme2n1" "nvme3n1" ]; }
      ];
      log = [
        { mirror = true; devices = [ "sda1" "sdb1" ]; }
      ];
      cache = [ "sda2" "sdb2" ];
      partition = {
        sda = {
          p1 = { sizeGB=10; };
          p2 = {};
        };
        sdb = {
          p1 = { sizeGB=10; };
          p2 = {};
        };
      };
    };
  };

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
