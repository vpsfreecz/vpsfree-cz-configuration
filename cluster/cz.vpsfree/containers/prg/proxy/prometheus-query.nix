{ lib }:
let
  authFile = "/var/lib/nginx-auth/prometheus-codex.htpasswd";
  postEndpoints = [
    "query"
    "query_range"
    "series"
    "labels"
  ];
  getEndpoints = [
    "metadata"
    "targets"
    "targets/metadata"
    "rules"
    "alerts"
    "status/buildinfo"
    "status/runtimeinfo"
  ];
  labelValues = "label/[a-zA-Z_][a-zA-Z0-9_]*/values";

  location = upstream: endpoint: methods: {
    basicAuthFile = authFile;
    proxyPass = upstream;
    recommendedProxySettings = false;
    extraConfig = ''
      # Reject alternate raw spellings before rewriting the normalized URI.
      if ($request_uri !~ "^/codex/api/v1/${endpoint}([?]|$)") { return 404; }
      if ($request_method !~ "^(${methods})$") { return 405; }
      rewrite ^/codex(/api/v1/.*)$ $1 break;
      proxy_set_header Authorization "";
      proxy_set_header Host $host;
      proxy_set_header Connection "";
      proxy_http_version 1.1;
      proxy_connect_timeout 5s;
      proxy_send_timeout 15s;
      proxy_read_timeout 30s;
      client_max_body_size 64k;
      client_body_timeout 10s;
      limit_req zone=prometheus_codex_rate burst=5 nodelay;
      limit_req_status 429;
      limit_conn prometheus_codex_connections 4;
      limit_conn_status 429;
    '';
  };
in
{
  # A constant key shares both budgets across vhosts and unauthenticated clients.
  # $remote_user is unavailable when nginx runs its limit phases.
  httpConfig = ''
    limit_req_zone prometheus-codex zone=prometheus_codex_rate:1m rate=2r/s;
    limit_conn_zone prometheus-codex zone=prometheus_codex_connections:1m;
  '';

  locations =
    upstream:
    lib.listToAttrs (
      map (
        endpoint:
        lib.nameValuePair "= /codex/api/v1/${endpoint}" (location upstream endpoint "GET|HEAD|POST")
      ) postEndpoints
      ++ map (
        endpoint: lib.nameValuePair "= /codex/api/v1/${endpoint}" (location upstream endpoint "GET|HEAD")
      ) getEndpoints
    )
    // {
      "~ ^/codex/api/v1/${labelValues}$" = location upstream labelValues "GET|HEAD";
      "= /codex".return = 404;
      "/codex/".return = 404;
    };
}
