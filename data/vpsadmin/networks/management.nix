{
  ipv4 = [
    { location = "prg"; address = "172.16.0.0"; prefix = 23; }
    { location = "brq"; address = "172.19.0.0"; prefix = 23; }
    { location = "pgnd"; address = "172.16.2.0"; prefix = 23; }

    # bgp prg
    { location = "prg"; address = "172.16.253.0"; prefix = 24; }
    { location = "prg"; address = "172.16.252.0"; prefix = 24; }
    { location = "prg"; address = "172.16.251.0"; prefix = 24; }
    { location = "prg"; address = "172.16.250.0"; prefix = 24; }

    # bgp brq
    { location = "brq"; address = "172.19.253.0"; prefix = 24; }
    { location = "brq"; address = "172.19.252.0"; prefix = 24; }
  ];

  dev = [
    { location = "prg"; address = "172.16.106.0"; prefix = 24; }
  ];

  dhcp = [
    { location = "prg"; address = "172.16.254.0"; prefix = 24; }
    { location = "brq"; address = "172.19.254.0"; prefix = 24; }
  ];
}
