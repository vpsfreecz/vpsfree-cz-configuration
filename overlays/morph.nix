self: super:
{
  morph = super.morph.overrideAttrs (oldAttrs: rec {
    name = oldAttrs.name + "-sorki";
    src = super.fetchFromGitHub {
      owner = "sorki";
      repo = "morph";
      rev = "d9396af1adeb7d9d012c2f75f7c90475464b12a4";
      sha256 = "1viwphxq7dm0zbgag6q2psibkbfhiylhp15s1i2wzlh0gnlslkd8";
    };
  });
}
