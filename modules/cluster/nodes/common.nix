{ config, lib, ... }:
with lib;
{
  options = {
    id = mkOption {
      type = types.nullOr types.ints.positive;
      description = "ID of this node in vpsAdmin";
      default = null;
    };

    role = mkOption {
      type = types.enum [ "hypervisor" "storage" ];
      description = ''
        Node role
      '';
    };
  };
}
