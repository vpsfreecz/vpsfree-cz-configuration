{ config, lib, ... }:
{
  config = {
    _module.args = {
      confLib = import ../../lib { inherit lib; };
    };
  };
}
