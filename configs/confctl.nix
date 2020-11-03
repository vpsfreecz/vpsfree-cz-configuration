{ config, ... }:
{
  confctl = {
    list.columns = [
      "name"
      "spin"
      "node.role"
      "host.name"
      "host.location"
      "host.domain"
    ];
  };
}
