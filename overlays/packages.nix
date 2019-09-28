self: super:
{
  graylogPlugins = super.graylogPlugins // (super.callPackage ../packages/graylog/plugins.nix {});

  havesnippet-client = super.callPackage ../packages/havesnippet-client {};

  morph = super.morph.overrideAttrs (oldAttrs: rec {
    name = "morph-vpsfree";
    src = super.fetchFromGitHub {
      owner = "vpsfreecz";
      repo = "morph";
      rev = "0436aa6eaf1e1bfe9735b32d084b71764a2e3073";
      sha256 = "100dk373ksnnyl4x1nv3igdrai39xlmi8d173ghgfaw5w6fw6kvh";
    };
  });

  sachet = super.callPackage ../packages/sachet {};
}
