{ pkgs, addr }:
{
  builderCommands = [
    {
      command = [
        "${pkgs.dnsutils}/bin/dig"
        "vpsfree.cz"
        "A"
        "+short"
        "@${addr}"
      ];
      standardOutput.match = "37.205.14.61\n";
    }
    {
      command = [
        "${pkgs.dnsutils}/bin/dig"
        "node1.stg.vpsfree.cz"
        "A"
        "+short"
        "@${addr}"
      ];
      standardOutput.match = "172.16.0.66\n";
    }
    {
      command = [
        "${pkgs.dnsutils}/bin/dig"
        "node1-mgmt.stg.vpsfree.cz"
        "A"
        "+short"
        "@${addr}"
      ];
      standardOutput.match = "172.16.101.44\n";
    }
  ];
}
