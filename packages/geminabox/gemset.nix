{
  builder = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0pw3r2lyagsxkm71bf44v5b74f7l9r7di22brbyji9fwz791hya9";
      type = "gem";
    };
    version = "3.3.0";
  };
  compact_index = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "12sam0njinsm62030lv7gsqhsqg1yqj9bpjdkxyqm4m8zi540v2w";
      type = "gem";
    };
    version = "0.15.0";
  };
  daemons = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "07cszb0zl8mqmwhc8a2yfg36vi6lbgrp4pa5bvmryrpcz9v6viwg";
      type = "gem";
    };
    version = "1.4.1";
  };
  eventmachine = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0wh9aqb0skz80fhfn66lbpr4f86ya2z5rx6gm5xlfhd05bj1ch4r";
      type = "gem";
    };
    version = "1.2.7";
  };
  faraday = {
    dependencies = [
      "faraday-net_http"
      "json"
      "logger"
    ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "09mcghancmn0s5cwk2xz581j3xm3xqxfv0yxg75axnyhrx9gy6f7";
      type = "gem";
    };
    version = "2.13.4";
  };
  faraday-net_http = {
    dependencies = [ "net-http" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0fxbckg468dabkkznv48ss8zv14d9cd8mh1rr3m98aw7wzx5fmq9";
      type = "gem";
    };
    version = "3.4.1";
  };
  geminabox = {
    dependencies = [
      "builder"
      "faraday"
      "httpclient"
      "nesty"
      "reentrant_flock"
      "sinatra"
    ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1c7a3jb88qyc4mdqf6kyn8k08xcr9gmd459lni0g47bw4a1qzwf7";
      type = "gem";
    };
    version = "2.1.0";
  };
  httpclient = {
    dependencies = [ "mutex_m" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1j4qwj1nv66v3n9s4xqf64x2galvjm630bwa5xngicllwic5jr2b";
      type = "gem";
    };
    version = "2.9.0";
  };
  json = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0s5vklcy2fgdxa9c6da34jbfrqq7xs6mryjglqqb5iilshcg3q82";
      type = "gem";
    };
    version = "2.13.2";
  };
  logger = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "00q2zznygpbls8asz5knjvvj2brr3ghmqxgr83xnrdj4rk3xwvhr";
      type = "gem";
    };
    version = "1.7.0";
  };
  mustermann = {
    dependencies = [ "ruby2_keywords" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0m70qz27mlv2rhk4j1li6pw797gmiwwqg02vcgxcxr1rq2v53rnb";
      type = "gem";
    };
    version = "2.0.2";
  };
  mutex_m = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0l875dw0lk7b2ywa54l0wjcggs94vb7gs8khfw9li75n2sn09jyg";
      type = "gem";
    };
    version = "0.3.0";
  };
  nesty = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "12s96dcbfvh20rj1hajgs9nz9h2p9q8926yav7x6svfljq5yjvhw";
      type = "gem";
    };
    version = "1.0.2";
  };
  net-http = {
    dependencies = [ "uri" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1ysrwaabhf0sn24jrp0nnp51cdv0jf688mh5i6fsz63q2c6b48cn";
      type = "gem";
    };
    version = "0.6.0";
  };
  rack = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1pcr8sn02lwzv3z6vx5n41b6ybcnw9g9h05s3lkv4vqdm0f2mq2z";
      type = "gem";
    };
    version = "2.2.17";
  };
  rack-protection = {
    dependencies = [ "rack" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1d6irsigm0i4ig1m47c94kixi3wb8jnxwvwkl8qxvyngmb73srl2";
      type = "gem";
    };
    version = "2.2.4";
  };
  reentrant_flock = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "074l9qhxwwypc29j7dypdpvqk649jwcn1r8kspd76z6ny48izzvx";
      type = "gem";
    };
    version = "0.1.1";
  };
  ruby2_keywords = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1vz322p8n39hz3b4a9gkmz9y7a5jaz41zrm2ywf31dvkqm03glgz";
      type = "gem";
    };
    version = "0.0.5";
  };
  rubygems-generate_index = {
    dependencies = [ "compact_index" ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0p1z76iqdn9py7m16jb4hxzn2fslw62n943ab3lrhrb6491l4w9m";
      type = "gem";
    };
    version = "1.1.3";
  };
  sinatra = {
    dependencies = [
      "mustermann"
      "rack"
      "rack-protection"
      "tilt"
    ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0wkc079h6hzq737j4wycpnv7c38mhd0rl33pszyy7768zzvyjc9y";
      type = "gem";
    };
    version = "2.2.4";
  };
  thin = {
    dependencies = [
      "daemons"
      "eventmachine"
      "logger"
      "rack"
    ];
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "1sddrm5n8jfvyqcmfhxrif6jsp1vla4wv9sx9f3c7xbphdjfbgav";
      type = "gem";
    };
    version = "2.0.1";
  };
  tilt = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "0w27v04d7rnxjr3f65w1m7xyvr6ch6szjj2v5wv1wz6z5ax9pa9m";
      type = "gem";
    };
    version = "2.6.1";
  };
  uri = {
    groups = [ "default" ];
    platforms = [ ];
    source = {
      remotes = [ "https://rubygems.org" ];
      sha256 = "04bhfvc25b07jaiaf62yrach7khhr5jlr5bx6nygg8pf11329wp9";
      type = "gem";
    };
    version = "1.0.3";
  };
}
