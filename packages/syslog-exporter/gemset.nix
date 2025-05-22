{
  base64 = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "01qml0yilb9basf7is2614skjp8384h2pycfx86cr8023arfj98g";
      type = "gem";
    };
    version = "0.2.0";
  };
  nio4r = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "1a9www524fl1ykspznz54i0phfqya4x45hqaz67in9dvw1lfwpfr";
      type = "gem";
    };
    version = "2.7.4";
  };
  prometheus-client = {
    dependencies = ["base64"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "0bzypdh2586iwl7m9xrhn1gglrvhx0mvz297ih0770h6x8ja09ni";
      type = "gem";
    };
    version = "4.2.4";
  };
  puma = {
    dependencies = ["nio4r"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "11xd3207k5rl6bz0qxhcb3zcr941rhx7ig2f19gxxmdk7s3hcp7j";
      type = "gem";
    };
    version = "6.6.0";
  };
  rack = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.org"];
      sha256 = "197wpw61cfwwdrwfdns0zx4mndrv1qn0y9b1v7g2d2nic2ckwayi";
      type = "gem";
    };
    version = "3.1.15";
  };
  syslog-exporter = {
    dependencies = ["prometheus-client" "puma" "rack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.vpsfree.cz"];
      sha256 = "0sc9krfwfvsfac4j2gzlngcdm1bb6zb8jnk0gdy5q0vxw5yp2vqq";
      type = "gem";
    };
    version = "0.13.2";
  };
}
