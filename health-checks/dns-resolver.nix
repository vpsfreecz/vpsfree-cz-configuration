{ pkgs, addr }:
{
  builderCommands = [
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "vpsfree.cz" "A" "+short" "@${addr}" ];
      standardOutput.match = "37.205.9.80\n";
    }
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "vpsfree.org" "A" "+short" "@${addr}" ];
      standardOutput.match = "37.205.9.80\n";
    }
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "havefun.cz" "A" "+short" "@${addr}" ];
    }
    {
      command = [ "${pkgs.dnsutils}/bin/dig" "google.com" "A" "+short" "@${addr}" ];
    }
  ];
}
