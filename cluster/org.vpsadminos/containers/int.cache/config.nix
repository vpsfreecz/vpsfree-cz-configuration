{ config, pkgs, lib, confLib, ... }:
let
  proxy = confLib.findConfig {
    cluster = config.cluster;
    name = "org.vpsadminos/containers/proxy";
  };
in {
  imports = [
    ../../../../environments/base.nix
    ../../../../profiles/ct.nix
  ];

  networking = {
    firewall.extraCommands = ''
      # Allow access from proxy
      iptables -A nixos-fw -p tcp --dport ${toString config.services.nix-serve.port} -s ${proxy.addresses.primary.address} -j nixos-fw-accept
    '';
  };

  services.nix-serve = {
    enable = true;
    secretKeyFile = "/private/nix-serve/cache-priv-key.pem";
    port = config.serviceDefinitions.nix-serve.port;
  };

  users.users.push = {
    shell = pkgs.bash;
    openssh.authorizedKeys.keys = [
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPgg6hoXJIMRJZiVULL8Ve3NweaiHPymiMgSQxFt7pFaLqACK4kxj+gKBg89V6TtEqHeHcI8fOV1ildGzzXNCGI= bbworker@nixos01.int.vpsadminos.org"
      "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBLQOOwoJuS4XQ3Aa54S2yC+aN+wLAgyKnSqFew2N8jbgpL8LnjGRVkOtlCgBDV5tqHpUqx0vk1QgMOgQvQju/oY= bbworker@nixos02.bb.int.vpsadminos.org"
    ];
  };

  nix.trustedUsers = [ "root" "push" ];
}
