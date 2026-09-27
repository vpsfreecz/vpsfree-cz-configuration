{
  systemd.unitProperties = {
    "nginx.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];
    "vpsadmin-webui-bff.service" = [
      {
        property = "ActiveState";
        value = "active";
      }
    ];
  };

  machineCommands = [
    {
      description = "Check private WebUI build provenance";
      command = [
        "bash"
        "-euo"
        "pipefail"
        "-c"
        ''curl --fail --silent --show-error --max-time 10 -H 'Host: newadmin.vpsfree.cz' http://172.16.9.170/build-info.json | jq -e '.schemaVersion == 1 and (.commit | type == "string" and length == 40 and test("^[0-9a-f]+$")) and (.dirty | type == "boolean")' >/dev/null''
      ];
    }
    {
      description = "Check private WebUI BFF liveness";
      command = [
        "bash"
        "-euo"
        "pipefail"
        "-c"
        ''test "$(curl --fail --silent --show-error --max-time 10 -H 'Host: newadmin.vpsfree.cz' http://172.16.9.170/healthz)" = ok''
      ];
    }
    {
      description = "Check anonymous WebUI session shape";
      command = [
        "bash"
        "-euo"
        "pipefail"
        "-c"
        ''curl --fail --silent --show-error --max-time 10 -H 'Host: newadmin.vpsfree.cz' -H 'Origin: https://newadmin.vpsfree.cz' -H 'Sec-Fetch-Site: same-origin' -H 'Accept: application/json' http://172.16.9.170/session.json | jq -e 'has("accessToken") and has("sessionKey") and has("sessionExpiresAt") and .accessToken == null and .sessionKey == null and .sessionExpiresAt == null' >/dev/null''
      ];
    }
  ];
}
