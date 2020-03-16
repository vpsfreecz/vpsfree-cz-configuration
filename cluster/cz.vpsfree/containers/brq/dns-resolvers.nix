{ config, ... }:
{
  cluster."cz.vpsfree".brq = {
    ns1 = {
      type = "container";
      spin = "other";
      container.id = 2865;
      addresses = {
        v4 = [ { address = "37.205.11.200"; prefix = 32; } ];
        v6 = [ { address = "2a03:3b40:100::1:200"; prefix = 128; } ];
      };
      services.unbound = {};
    };

    ns2 = {
      type = "container";
      spin = "other";
      container.id = 2866;
      addresses = {
        v4 = [ { address = "37.205.11.222"; prefix = 32; } ];
        v6 = [ { address = "2a03:3b40:100::1:222"; prefix = 128; } ];
      };
      services.unbound = {};
    };
  };
}
