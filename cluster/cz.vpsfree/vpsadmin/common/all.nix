{ config, ... }:
{
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
    <vpsadmin/nixos/modules/nixos-modules.nix>
  ];

  vpsadmin = {
    plugins = [
      "monitoring"
      "newslog"
      "outage_reports"
      "payments"
      "requests"
      "webui"
    ];
  };
}
