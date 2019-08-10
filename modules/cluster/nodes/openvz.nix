{ config, lib, ... }:
with lib;
{
  options = {
    role = mkOption {
      type = types.enum [ "hypervisor" "storage" ];
      description = ''
        Node role
      '';
    };
  };
}
