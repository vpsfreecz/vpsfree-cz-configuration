{ lib }:
let
  levels = {
    "warning" = "Warn";
    "critical" = "Crit";
    "fatal" = "Fatal";
  };

  rules = lib.mapAttrsToList (k: v: {
    alert = "Test${v}Alert";
    expr = "test_alert_${k} == 1";
    labels = {
      severity = k;
    };
    annotations = {
      summary = "Test alert, no real issue (instance {{ $labels.instance }})";
      description = ''
        Test ${k} alert, no real issue

        LABELS: {{ $labels }}
      '';
    };
  }) levels;
in [
  {
    name = "test";
    rules = rules;
  }
]
