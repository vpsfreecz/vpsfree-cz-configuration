{ config, ... }:
{
  cluster."cz.vpsfree".global = {
    ns1 = {
      type = "container";
      spin = "other";
      container.id = 1012;
      addresses = {
        v4 = [ { address = "77.93.223.251"; prefix = 32; } ];
        v6 = [ { address = "	2a01:430:17:1::ffff:179"; prefix = 128; } ];
      };
      services.bind = {};
    };

    ns2 = {
      type = "container";
      spin = "other";
      container.id = 1013;
      addresses = {
        v4 = [ { address = "37.205.11.51"; prefix = 32; } ];
        v6 = [ { address = "	2a03:3b40:100::1:51"; prefix = 128; } ];
      };
      services.bind = {};
    };
  };
}
