{ config, lib, pkgs, ... }:
{
  config = {
    _module.args = {
      confLib = import ../../lib { inherit lib pkgs; };
    };
  };
}
