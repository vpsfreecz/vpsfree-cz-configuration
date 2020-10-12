self: super:
{
  graylogPlugins = super.graylogPlugins // (super.callPackage ../packages/graylog/plugins.nix {});

  havesnippet-client = super.callPackage ../packages/havesnippet-client {};

  morph = super.morph.overrideAttrs (oldAttrs: rec {
    name = "morph-vpsfree";
    src = super.fetchFromGitHub {
      owner = "vpsfreecz";
      repo = "morph";
      rev = "b9e1e4f3c577119c65a394f1b6aedc183b319474";
      sha256 = "sha256:1w0cid6anvy776k9gl32s20lixn9nmai5wxhaybxnpzxdda28c6p";
    };
  });

  sachet = super.callPackage ../packages/sachet {};
}
