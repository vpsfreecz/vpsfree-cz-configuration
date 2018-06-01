{ config, ...}:

let
  bgpAS = 4200001001;
  kernelProto = {
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
in
{
  networking.bird = {
    enable = true;
    protocol.kernel = kernelProto;
    protocol.bgp = {
      bgp1 = rec {
        as = bgpAS;
        nextHopSelf = true;
        neighbor = { "172.16.251.1" = 4200001901; };
        extraConfig = ''
          export all;
          import all;
        '';
      };
      bgp2 = rec {
        as = bgpAS;
        nextHopSelf = true;
        neighbor = { "172.16.250.1" = 4200001902; };
        extraConfig = ''
          export all;
          import all;
        '';
      }; 
    };
  };

  networking.bird6 = {
    enable = true;
    protocol.kernel = kernelProto;
    protocol.bgp = {
      bgp1 = rec {
        as = bgpAS;
        nextHopSelf = true;
        neighbor = { "2a03:3b40:42:2:01::1" = 4200001901; };
        extraConfig = ''
          export all;
          import all;
        '';
      };
      bgp2 = rec {
        as = bgpAS;
        nextHopSelf = true;
        neighbor = { "2a03:3b40:42:3:01::1" = 4200001902; };
        extraConfig = ''
          export all;
          import all;
        '';
      }; 
    };
  };
}
