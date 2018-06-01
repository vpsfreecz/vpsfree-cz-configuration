{ config, ...}:
{
  imports = [
    ./brq.nix
  ];
  networking.hostName = "node4.brq";

  #boot.zfs.pool.layout = "mirror sda sdb";
  #boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" "panic=-1" ];
  #boot.consoleLogLevel = 4;

  networking.bird.routerId = "1.2.3.4";
  networking.bird6.routerId = "1.2.3.4";
}
