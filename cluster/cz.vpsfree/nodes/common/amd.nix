{ config, ... }:
{
  boot.kernelParams = [ "amd_pstate=active" ];
}
