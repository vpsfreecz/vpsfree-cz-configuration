{ discourse, lib }:

discourse.mkDiscoursePlugin {
  name = "discourse-vpsadmin-oauth-signup-policy";
  src = ./.;

  meta = {
    description = "Allow Discourse account creation only after vpsAdmin OAuth";
    license = lib.licenses.mit;
  };
}
