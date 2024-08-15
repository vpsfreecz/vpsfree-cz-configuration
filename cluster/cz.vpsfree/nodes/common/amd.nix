{ config, ... }:
{
  hardware.cpu.amd.updateMicrocode = true;

  boot.kernelParams = [ "amd_pstate=guided" ];
}
