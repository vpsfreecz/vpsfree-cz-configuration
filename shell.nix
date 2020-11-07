if builtins.pathExists ../confctl/shell.nix then
  import ../confctl/shell.nix
else if builtins.pathExists ../../confctl/shell.nix then
  import ../../confctl/shell.nix
else builtins.abort "Unable to find confctl shell"
