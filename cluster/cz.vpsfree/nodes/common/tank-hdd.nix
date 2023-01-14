{ config, lib, pkgs, ... }:
{
  # Scrub HDD-backed nodes only between 23h-07h
  boot.zfs.pools.tank.scrub = {
    pauseIntervals = [ "0 7 * * *" ];
    resumeIntervals = [ "0 23 * * *" ];
  };
}
