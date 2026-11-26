{
  base64 = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0yx9yn47a8lkfcjmigk79fykxvr80r4m1i35q82sxzynpbm7lcr7";
      type = "gem";
    };
    version = "0.3.0";
  };
  nio4r = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "18fwy5yqnvgixq3cn0h63lm8jaxsjjxkmj8rhiv8wpzv9271d43c";
      type = "gem";
    };
    version = "2.7.5";
  };
  prometheus-client = {
    dependencies = [ "base64" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "09ajgmp3zvr417wasyr2imqg6f2kx0avx42dh56rzk9cx71ynyw0";
      type = "gem";
    };
    version = "4.2.5";
  };
  puma = {
    dependencies = [ "nio4r" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1a63p02hgv785rkvkvhrcy244wdyx93i8nssy8z8l3zjn8gy2bd1";
      type = "gem";
    };
    version = "8.1.3";
  };
  rack = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1k0d8vpg160wjnp344wyn3jp70c8paz3nhglrzninihciz8c2dc2";
      type = "gem";
    };
    version = "3.2.9";
  };
  ssh-exporter = {
    dependencies = [
      "prometheus-client"
      "puma"
      "rack"
    ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      fetchSubmodules = false;
      rev = "c1b481a68e00d90802aeb36730c68a19f3c17711";
      sha256 = "1b36a49xrhdqr6xh99kxnlf8mk415kj29n339q3wi65wx1dzgagz";
      type = "git";
      url = "https://github.com/vpsfreecz/ssh-exporter.git";
    };
    version = "0.3.2";
  };
}
