{ config, pkgs, lib, ... }:
{
  boot.zfs.pools.tank.datasets = {
    "image-repository/build-scripts" = {};
    "image-repository/build-dataset" = {};
    "image-repository/cache" = {};
    "image-repository/log" = {};
    "image-repository/target" = {};
  };

  services.osctl.image-repository.vpsadminos = rec {
    path = "/tank/image-repository/target";
    cacheDir = "/tank/image-repository/cache";
    buildScriptDir = "/tank/image-repository/build-scripts";
    buildDataset = "tank/image-repository/build-dataset";
    logDir = "/tank/image-repository/log";

    rebuildAll = true;
    buildInterval = "0 4 * * sat";

    postBuild = ''
      ${pkgs.rsync}/bin/rsync -av --delete "${path}/" images.int.vpsadminos.org:/srv/images/
    '';

    vendors.vpsadminos = { defaultVariant = "minimal"; };
    defaultVendor = "vpsadminos";

    images = {
      almalinux = {
        "8" = { tags = [ "latest" "stable" ]; };
      };

      alpine = {
        "3.12" = {};
        "3.13" = {};
        "3.14" = { tags = [ "latest" "stable" ]; };
      };

      arch.rolling = { name = "arch"; tags = [ "latest" "stable" ]; };

      centos = {
        "7" = {};
        "8" = { tags = [ "latest" "stable" ]; };
        "stream" = { tags = [ "latest-stream" ]; };
      };

      debian = {
        "9" = {};
        "10" = {};
        "11" = { tags = [ "latest" "stable" ]; };
        "testing" = { tags = [ "testing" ]; };
        "unstable" = { tags = [ "unstable" ]; };
      };

      devuan = {
        "2.0" = {};
        "3.0" = { tags = [ "latest" "stable" ]; };
      };

      fedora = {
        "33" = {};
        "34" = { tags = [ "latest" "stable" ]; };
      };

      gentoo.rolling = { name = "gentoo"; tags = [ "latest" "stable" ]; };

      nixos = {
        "21.05" = { tags = [ "latest" "stable" ]; };
        "unstable" = { tags = [ "unstable" ]; };
      };

      opensuse = {
        "leap-15.2" = {};
        "leap-15.3" = { tags = [ "latest" "stable" ]; };
        "tumbleweed" = { tags = [ "latest-tumbleweed" ]; };
      };

      rocky = {
        "8" = { tags = [ "latest" ]; };
      };

      slackware."14.2" = { tags = [ "latest" "stable" ]; };

      ubuntu = {
        "18.04" = {};
        "20.04" = { tags = [ "latest" "stable" ]; };
      };

      void = {
        "glibc" = { tags = [ "latest" "stable" "latest-glibc" "stable-glibc" ]; };
        "musl" = { tags = [ "latest-musl" "stable-musl" ]; };
      };
    };

    garbageCollection = [
      {
        distribution = "arch";
        version = "\\d+";
        keep = 4;
      }
      {
        distribution = "centos";
        version = "stream-\\d+";
        keep = 4;
      }
      {
        distribution = "debian";
        version = "testing-\\d+";
        keep = 4;
      }
      {
        distribution = "debian";
        version = "unstable-\\d+";
        keep = 4;
      }
      {
        distribution = "gentoo";
        version = "\\d+";
        keep = 4;
      }
      {
        distribution = "nixos";
        version = "unstable-\\d+";
        keep = 4;
      }
      {
        distribution = "opensuse";
        version = "tumbleweed-\\d+";
        keep = 4;
      }
      {
        distribution = "void";
        version = "glibc-\\d+";
        keep = 4;
      }
      {
        distribution = "void";
        version = "musl-\\d+";
        keep = 4;
      }
    ];
  };
}
