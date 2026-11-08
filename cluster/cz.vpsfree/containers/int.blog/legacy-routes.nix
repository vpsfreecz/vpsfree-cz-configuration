{ config, lib, ... }:
let
  projection = builtins.fromJSON (builtins.readFile ../../../../data/blog-legacy-routes.json);
  aliases = projection.aliases;
  sourceValid =
    value: builtins.match "/[A-Za-z0-9._~%/?=&+-]*" value != null && !(lib.hasPrefix "//" value);
  targetValid =
    value:
    builtins.match "/[A-Za-z0-9._~%/+-]+(#[A-Za-z0-9_-]+)?" value != null
    && !(lib.hasPrefix "//" value)
    && !(lib.elem ".." (lib.splitString "/" value));
  valid =
    projection.schema == 1
    && builtins.match "[0-9a-f]{64}" projection.source_manifest_sha256 != null
    && builtins.length aliases == 540
    && builtins.length (lib.unique (map (row: row.source) aliases)) == 540
    && lib.all (
      row:
      builtins.attrNames row == [
        "kind"
        "source"
        "target"
      ]
      && sourceValid row.source
      && targetValid row.target
    ) aliases;
  mapping =
    row:
    # Quoted, case-sensitive regex keys preserve the captured request URI bytes.
    "${builtins.toJSON ("~^" + lib.escapeRegex row.source + "$")} ${
      builtins.toJSON ("https://blog.vpsfree.cz" + row.target)
    };";
in
{
  config = lib.mkIf config.services.vpsfree-static-blog.enable {
    assertions = [
      {
        assertion = valid;
        message = "Blog legacy routes must be the finite validated 540-alias projection.";
      }
    ];
    services.nginx.appendHttpConfig = ''
      map $request_uri $blog_legacy_redirect {
        default "";
        "~^/\\?feed=rss2$" "https://blog.vpsfree.cz/feed/";
        ${lib.concatMapStringsSep "\n" mapping aliases}
      }
      map $args $blog_legacy_identity_query {
        default 0;
        "~*(^|&)(p|attachment_id|author|cat|replytocom|feed)(=|&|$)" 1;
      }
    '';
    services.nginx.virtualHosts.static-blog-cs.extraConfig = ''
      if ($blog_legacy_redirect != "") {
        return 301 $blog_legacy_redirect;
      }
      if ($blog_legacy_identity_query) {
        return 404;
      }
    '';
  };
}
