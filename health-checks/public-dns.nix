{ pkgs, ns }:
{
  builderCommands = [
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "vpsfree.cz" "A" "+short" "@${ns}" ];
      standardOutput.match = "37.205.14.61\n";
    }
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "vpsfree.cz" "AAAA" "+short" "@${ns}" ];
      standardOutput.match = "2a03:3b40:fe:35::1\n";
    }
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "vpsadmin.vpsfree.cz" "A" "+short" "@${ns}" ];
      standardOutput.match = "proxy.prg.vpsfree.cz.\n37.205.14.61\n";
    }
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "vpsadmin.vpsfree.cz" "AAAA" "+short" "@${ns}" ];
      standardOutput.match = "proxy.prg.vpsfree.cz.\n2a03:3b40:fe:35::1\n";
    }
  ];
}
