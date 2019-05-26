{ config, lib, ...}:
with lib;

let
  cfg = config.node.serial;
in
{
  options = {
    node.serial = {
      enable = mkEnableOption "Enable serial console output";
      baudRate = mkOption {
        type = types.ints.positive;
        description = "Serial baudrate";
        default = 115200;
      };
    };
  };
  config = mkIf cfg.enable {
    boot.kernelParams = [ "console=tty0" "console=ttyS0,${toString cfg.baudRate}" "panic=-1" ];
  };
}
