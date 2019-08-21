# Based on
#  https://medium.com/@tom.fawcett/time-of-day-based-notifications-with-prometheus-and-alertmanager-1bf7a23b7695
[
  {
    name = "time-of-day";
    rules = [
      {
        record = "is_european_summer_time";
        expr = ''
          (vector(1) and (month() > 3 and month() < 10))
          or
          (vector(1) and (month() == 3 and (day_of_month() - day_of_week()) >= 25) and absent((day_of_month() >= 25) and (day_of_week() == 0)))
          or
          (vector(1) and (month() == 10 and (day_of_month() - day_of_week()) < 25) and absent((day_of_month() >= 25) and (day_of_week() == 0)))
          or
          (vector(1) and ((month() == 10 and hour() < 1) or (month() == 3 and hour() > 0)) and ((day_of_month() >= 25) and (day_of_week() == 0)))
          or
          vector(0)
        '';
      }

      {
        record = "europe_prague_time";
        expr = "time() + 3600 + 3600 * is_european_summer_time";
      }

      {
        record = "europe_prague_hour";
        expr = "hour(europe_prague_time)";
      }

      {
        alert = "QuietHours";
        expr = "europe_prague_hour >= 23 or europe_prague_hour <= 6";
        for = "1m";
        labels = {
          severity = "none";
        };
        annotations = {
          description = ''
            This alert fires during quiet hours. It should be blackholed by Alertmanager.
          '';
        };
      }
    ];
  }
]
