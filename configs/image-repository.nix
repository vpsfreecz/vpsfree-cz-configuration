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
        "3.13" = {};
        "3.14" = {};
        "3.15" = { tags = [ "latest" "stable" ]; };
      };

      arch.rolling = { name = "arch"; tags = [ "latest" "stable" ]; };

      centos = {
        "7" = {};
        "8" = { tags = [ "latest" "stable" ]; };
        "8-stream" = { tags = [ "latest-8-stream" ]; };
        "9-stream" = { tags = [ "latest-9-stream" "latest-stream" ]; };
      };

      debian = {
        "9" = {};
        "10" = {};
        "11" = { tags = [ "latest" "stable" ]; };
        "testing" = { tags = [ "testing" ]; };
        "unstable" = { tags = [ "unstable" ]; };
      };

      devuan = {
        "3.0" = {};
        "4" = { tags = [ "latest" "stable" ]; };
      };

      fedora = {
        "34" = {};
        "35" = { tags = [ "latest" "stable" ]; };
      };

      gentoo.rolling = { name = "gentoo"; tags = [ "latest" "stable" ]; };

      nixos = {
        "21.11" = { tags = [ "latest" "stable" ]; };
        "unstable" = { tags = [ "unstable" ]; };
      };

      opensuse = {
        "leap-15.2" = {};
        "leap-15.3" = { tags = [ "latest" "stable" ]; };
        "tumbleweed" = { tags = [ "latest-tumbleweed" ]; };
      };

      rocky = {
        "8" = { tags = [ "latest" "stable" ]; };
      };

      slackware = {
        "15.0" = { tags = [ "latest" "stable" ]; };
        "current" = { tags = [ "latest-current" ]; };
      };

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
        version = "8-stream-\\d+";
        keep = 4;
      }
      {
        distribution = "centos";
        version = "9-stream-\\d+";
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
        distribution = "slackware";
        version = "current-\\d+";
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
