let
  lvirt = {
    deployment.targetEnv = "libvirtd";
    deployment.libvirtd.headless = true;
    deployment.libvirtd.extraDevicesXML = ''
      <serial type='pty'>
        <target port='0'/>
      </serial>
      <console type='pty'>
        <target type='serial' port='0'/>
      </console>
    '';
  };
in
{
  network.description = "testing infrastructure";

  netboot     = lvirt;
  hydra       = lvirt;
  hydra_slave = lvirt;
}
