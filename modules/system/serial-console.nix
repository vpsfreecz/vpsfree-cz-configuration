{ config, lib, ... }:
with lib;
let
  cfg = config.system.serial-console;
in {
  options = {
    system.serial-console = {
      enable = mkOption {
        default = true;
        example = true;
        description = "Whether to enable serial-console.";
        type = lib.types.bool;
      };

      device = mkOption {
        type = types.str;
        description = "Device node in /dev";
        default = "ttyS1";
      };

      baudRate = mkOption {
        type = types.ints.positive;
        description = "Serial baudrate";
        default = 115200;
      };
    };
  };

  config = mkIf cfg.enable {
    boot.kernelParams = [
      "console=tty0"
      "console=${cfg.device},${toString cfg.baudRate}"
      "panic=-1"
    ];
  };
}
