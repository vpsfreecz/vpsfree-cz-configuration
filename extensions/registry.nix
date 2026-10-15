{
  boundSourcePaths = [
    "flake.nix"
    "flake.lock"
    "extensions/go.mod"
    "extensions/go.sum"
    "extensions/default.nix"
    "extensions/registry.nix"
    "extensions/cmd/vpsfree-confctl-ext/main.go"
    "extensions/internal/site/site.go"
    "extensions/internal/site/site_test.go"
    "extensions/internal/site/protocol_test.go"
  ];

  declarations = executable: [
    {
      id = "vpsfree.netboot";
      protocol = {
        major = 1;
        minor = 0;
      };
      argv = [ executable ];
      hooks = [
        {
          event = "rediscover.after-write";
          handler = "netboot.rediscover";
          order = 100;
        }
      ];
    }
    {
      id = "vpsfree.runtime-kernels";
      protocol = {
        major = 1;
        minor = 0;
      };
      argv = [ executable ];
      groups = [
        {
          path = [ "runtime-kernels" ];
          description = "Manage node runtime kernel versions";
        }
      ];
      commands = [
        {
          path = [
            "runtime-kernels"
            "update"
          ];
          handler = "runtime.update";
          description = "Update runtime kernels";
          option_sets = [
            "machine-filter"
            "confirmation"
          ];
          arguments = [
            {
              name = "machine-pattern";
              required = false;
            }
          ];
        }
      ];
      hooks = [
        {
          event = "deploy.prepare";
          handler = "runtime.prepare";
          order = 100;
        }
      ];
    }
  ];
}
