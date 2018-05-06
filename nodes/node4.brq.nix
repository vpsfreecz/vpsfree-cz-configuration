{ config, ...}:
{
  networking.hostName = "node4.brq";

  #networking.bird.routerId = "1.2.3.4";

  #boot.zfs.pool.layout = "mirror sda sdb";
  #boot.kernelParams = [ "console=tty0" "console=ttyS0,115200" "panic=-1" ];
  #boot.consoleLogLevel = 4;

  networking.bird = {
    enable = true;
    routerId = "1.2.3.4";
    protocol.bgp = {
      bgp1 = rec {
        as = 65500;
        nextHopSelf = true;
        neighbor = { "172.17.4.1" = as; };
        extraConfig = ''
          export all;
          import all;
        '';
      };
    };

    protocol.kernel = {
      learn = true;
      persist = true;
      extraConfig = ''
        export all;
        import all;
        import filter {
          if net.len > 25 then accept;
          reject;
        };
      '';
    };
  };

  networking.bird6 = {
    enable = true;
    routerId = "1.2.3.4";
    protocol.bgp = {
      bgp1 = rec {
        as = 65500;
        nextHopSelf = true;
        neighbor = { "2a03:3b40:7:5::1" = as; };
        extraConfig = ''
          export all;
          import all;
        '';
      };
    };

    protocol.kernel = {
      learn = true;
      persist = true;
      extraConfig = ''
        export all;
        import all;
        import filter {
          if net.len > 25 then accept;
          reject;
        };
      '';
    };
  };

}
