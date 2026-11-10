{
  lib,
  fetchFromGitHub,
  rustPlatform,
  python3,
}:
let
  src = fetchFromGitHub {
    owner = "vpsfreecz";
    repo = "syslog-exporter";
    rev = "891db6b82ccd37e985507c654050143e165041a7";
    hash = "sha256-eWPE7ZtE8d4+D8Jr0Dm40ykjoW6PBtLGqMI2GJLhDNI=";
  };
  manifest = builtins.fromTOML (builtins.readFile (src + "/Cargo.toml"));
in
rustPlatform.buildRustPackage {
  pname = manifest.package.name;
  version = manifest.package.version;
  inherit src;

  cargoHash = "sha256-dvnEEbDRJoHlHLj/EDXp21PYrnvx5+J1+BGYQkmN7yI=";
  nativeCheckInputs = [ python3 ];

  meta = {
    inherit (manifest.package) description;
    homepage = "https://github.com/vpsfreecz/syslog-exporter";
    platforms = lib.platforms.linux;
    maintainers = [ ];
    license = lib.licenses.mit;
    mainProgram = "syslog-exporter";
  };
}
