{ discourse, lib }:

discourse.mkDiscoursePlugin {
  name = "discourse-oauth-signup-policy";
  src = ./.;

  meta = {
    description = "Allow Discourse account creation only after approved OAuth";
    license = lib.licenses.mit;
  };
}
