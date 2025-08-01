{
  pkgs,
  lib,
  config,
  confMachine,
  ...
}:
with lib;
let
  alerters = [
    "https://alerts1.prg.vpsfree.cz"
    "https://alerts2.prg.vpsfree.cz"
  ];

  httpConfigFile = pkgs.writeText "am-http-config.yml" (
    builtins.toJSON {
      basic_auth = {
        username = "node";
        password_file = "/var/secrets/alertmanager-http-password";
      };
    }
  );
in
{
  environment.etc = {
    "amtool/config.yml".text = builtins.toJSON {
      "alertmanager.url" = elemAt alerters 0;
      "author" = confMachine.host.fqdn;
      "require-comment" = false;
      "http.config.file" = httpConfigFile;
    };
  };

  environment.systemPackages = with pkgs; [ prometheus-alertmanager ];

  runit.halt.hooks = {
    "alertmanager-silence".source = pkgs.writeScript "alertmanager-silence" ''
      #!${pkgs.bash}/bin/bash

      [ "$HALT_HOOK" != "pre-system" ] && exit 0

      comment="System $HALT_ACTION

      $HALT_REASON"
      retval=

      for alerter in ${concatStringsSep " " alerters} ; do
        echo "Silencing fqdn=${confMachine.host.fqdn} on $alerter"
        ${pkgs.prometheus-alertmanager}/bin/amtool silence add \
          --alertmanager.url=$alerter \
          --timeout=5s \
          --author=$USER@${confMachine.host.fqdn} \
          --comment="$comment" \
          --duration=20m \
          fqdn=${confMachine.host.fqdn}
        retval=$?
        [ $retval == 0 ] && exit 0
      done

      exit $retval
    '';
  };
}
