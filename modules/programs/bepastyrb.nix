{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.bepastyrb;

  settingsFormat = pkgs.formats.json { };

  configurationJson = settingsFormat.generate "bepastyrb.yml" cfg.settings;
in
{
  options = {
    programs.bepastyrb = {
      enable = mkEnableOption "Include bepastyrb, a ruby-bepasty-client CLI";

      settings = mkOption {
        type = types.submodule {
          freeformType = settingsFormat.type;

          options = {
            server = mkOption {
              type = types.str;
              default = "https://paste.vpsfree.cz";
              description = "URL to the bepasty server.";
            };

            password_file = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "File with a password to authenticate the user.";
            };

            max_life = {
              unit = mkOption {
                type = types.enum [ "minutes" "hours" "days" "weeks" "months" "forever" ];
                default = "months";
                description = ''
                  Unit for file max life
                '';
              };

              value = mkOption {
                type = types.ints.positive;
                default = 6;
                description = ''
                  Value for file max life
                '';
              };
            };
          };
        };
        default = {};
        description = ''
          bepastyrb settings, see man bepastyrb(1)
        '';
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      environment.systemPackages = [ pkgs.ruby-bepasty-client ];
      environment.etc."bepastyrb.yml".source = configurationJson;
    })
  ];
}
