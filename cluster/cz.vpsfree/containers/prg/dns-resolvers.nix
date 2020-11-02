{ config, ... }:
{
  cluster = {
    "cz.vpsfree/containers/prg/ns1" = {
      spin = "other";
      container.id = 2864;
      host = { name = "ns1"; location = "prg"; domain = "vpsfree.cz"; };
      addresses = {
        v4 = [ { address = "37.205.9.100"; prefix = 32; } ];
        v6 = [ { address = "2a01:430:17:1::ffff:666"; prefix = 128; } ];
      };
      services.unbound = {};
    };

    "cz.vpsfree/containers/prg/ns2" = {
      spin = "other";
      container.id = 2867;
      host = { name = "ns2"; location = "prg"; domain = "vpsfree.cz"; };
      addresses = {
        v4 = [ { address = "37.205.10.88"; prefix = 32; } ];
        v6 = [ { address = "2a01:430:17:1::ffff:588"; prefix = 128; } ];
      };
      services.unbound = {};
    };
  };
}
