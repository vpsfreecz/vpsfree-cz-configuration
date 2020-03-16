{ config, ... }:
{
  cluster."cz.vpsfree".prg = {
    ns1 = {
      type = "container";
      spin = "other";
      container.id = 2864;
      addresses = {
        v4 = [ { address = "37.205.9.100"; prefix = 32; } ];
        v6 = [ { address = "2a01:430:17:1::ffff:666"; prefix = 128; } ];
      };
      services.unbound = {};
    };

    ns2 = {
      type = "container";
      spin = "other";
      container.id = 2867;
      addresses = {
        v4 = [ { address = "37.205.10.88"; prefix = 32; } ];
        v6 = [ { address = "2a01:430:17:1::ffff:588"; prefix = 128; } ];
      };
      services.unbound = {};
    };
  };
}
