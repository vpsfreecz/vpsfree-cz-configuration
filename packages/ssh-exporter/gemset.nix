{
  daemons = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.vpsfree.cz"];
      sha256 = "07cszb0zl8mqmwhc8a2yfg36vi6lbgrp4pa5bvmryrpcz9v6viwg";
      type = "gem";
    };
    version = "1.4.1";
  };
  eventmachine = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.vpsfree.cz"];
      sha256 = "0wh9aqb0skz80fhfn66lbpr4f86ya2z5rx6gm5xlfhd05bj1ch4r";
      type = "gem";
    };
    version = "1.2.7";
  };
  prometheus-client = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.vpsfree.cz"];
      sha256 = "11k1r8mfr0bnd574yy08wmpzbgq8yqw3shx7fn5f6hlmayacc4bh";
      type = "gem";
    };
    version = "4.0.0";
  };
  rack = {
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.vpsfree.cz"];
      sha256 = "1qgwkcb8kxns8d5187cxjaxf18b7dmg9gh6cr9c1125m0bj2pnfk";
      type = "gem";
    };
    version = "2.2.6.4";
  };
  ssh-exporter = {
    dependencies = ["prometheus-client" "thin"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.vpsfree.cz"];
      sha256 = "1jpxcwwqip6b0p0z8fkq00zby24wl4bbkvwnzmx6a0bjw2070yn1";
      type = "gem";
    };
    version = "0.1.0";
  };
  thin = {
    dependencies = ["daemons" "eventmachine" "rack"];
    groups = ["default"];
    platforms = [];
    source = {
      remotes = ["https://rubygems.vpsfree.cz"];
      sha256 = "08g1yq6zzvgndj8fd98ah7pp8g2diw28p8bfjgv7rvjvp8d2am8w";
      type = "gem";
    };
    version = "1.8.2";
  };
}
