{ pkgs,  stdenv, fetchurl, unzip, graylog }:

with pkgs.lib;

let
  glPlugin = a@{
    pluginName,
    version,
    unpackPhase ? ''
      :
    '',
    installPhase ? ''
      mkdir -p $out/bin
      cp $src $out/bin/${pluginName}-${version}.jar
    '',
    ...
  }:
    stdenv.mkDerivation (a // {
      inherit unpackPhase installPhase;
      dontUnpack = true;
      buildInputs = [ unzip ];
      meta = a.meta // {
        platforms = graylog.meta.platforms;
        maintainers = (a.meta.maintainers or []) ++ [ maintainers.fadenb ];
      };
    });
in {
  alertmanager-callback = glPlugin rec {
    name = "graylog-alertmanager-callback-${version}";
    pluginName = "graylog-plugin-alertmanagercallback";
    version = "1.2";
    src = fetchurl {
      url = "https://github.com/GDATASoftwareAG/Graylog-Plugin-AlertManager-Callback/releases/download/${version}/${pluginName}-${version}.jar";
      sha256 = "13h3rv4vnwn4fanc4sizwd9dsq6rg3lsnymnkpi5wzyrhb0x7gak";
    };
    meta = {
      homepage = https://github.com/GDATASoftwareAG/Graylog-Plugin-AlertManager-Callback;
      description = "A plugin for Graylog which provides the possibility to send alerts to the Prometheus AlertManager API.";
    };
  };
}
