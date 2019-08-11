{ config, lib, ... }:
with lib;
{
  options = {
    id = mkOption {
      type = types.ints.positive;
      description = "ID of this node in vpsAdmin";
    };

    role = mkOption {
      type = types.enum [ "hypervisor" "storage" ];
      description = ''
        Node role
      '';
    };
  };
}
