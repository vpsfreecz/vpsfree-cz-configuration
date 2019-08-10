{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.programs.havesnippet;
  values = [ "public" "unlisted" "logged" "private" ];
  valueIndexes = imap0 (i: v: { name = v; index = i; }) values;
  indexOf = v: (
    findFirst ({name, ...}: name == v) (elemAt valueIndexes 1) valueIndexes
  ).index;
in
{
  options = {
    programs.havesnippet = {
      enable = mkEnableOption "Include CLI for HaveSnippet";

      url = mkOption {
        type = types.str;
        default = "https://paste.vpsfree.cz";
        description = "URL to the HaveSnippet server instance.";
      };

      apiKey = mkOption {
        type = types.str;
        default = "";
        description = "API key used to authenticate the user.";
      };

      accessibility = mkOption {
        type = types.enum values;
        default = "unlisted";
        description = "Default paste visitibility setting.";
      };

      expiration = mkOption {
        type = types.ints.unsigned;
        default = 12 * 30 * 24 * 60 * 60;
        description = "Default paste expiration in seconds.";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      environment.systemPackages = [ pkgs.havesnippet-client ];
      environment.etc."havesnippet-client".text = ''
        ---
        :url: ${cfg.url}
        ${optionalString (cfg.apiKey != "") ":api_key: ${cfg.apiKey}"}
        :accessibility: ${toString (indexOf cfg.accessibility)}
        :expiration_interval: ${toString cfg.expiration}
      '';
    })
  ];
}
