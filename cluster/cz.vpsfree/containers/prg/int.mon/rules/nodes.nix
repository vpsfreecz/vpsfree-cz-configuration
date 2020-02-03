[
  {
    name = "nodes";
    interval = "20s";
    rules = [
      {
        alert = "NodeExporterDown";
        expr = ''up{job="nodes"} == 0'';
        for = "5m";
        labels = {
          severity = "critical";
          frequency = "2m";
        };
        annotations = {
          summary = "Exporter down (instance {{ $labels.instance }})";
          description = ''
            Prometheus exporter down

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorBooting";
        expr = ''time() - node_boot_time_seconds{role="hypervisor"} < 2400'';
        labels = {
          severity = "none";
        };
        annotations = {
          description = ''
            This alert fires when a node is booting. It can be used to inhibit
            other alerts. It should be blackholed by Alertmanager.
          '';
        };
      }

      {
        alert = "HypervisorHighCpuLoad";
        expr = ''100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="hypervisor"}[5m])) * 100) > 80 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "10m";
        labels = {
          alertclass = "cpuload";
          severity = "warning";
        };
        annotations = {
          summary = "High CPU load (instance {{ $labels.instance }})";
          description = ''
            CPU load is > 80%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorCritCpuLoad";
        expr = ''100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="hypervisor"}[5m])) * 100) > 90 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "10m";
        labels = {
          alertclass = "cpuload";
          severity = "critical";
        };
        annotations = {
          summary = "Critical CPU load (instance {{ $labels.instance }})";
          description = ''
            CPU load is > 90%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorHighIoWait";
        expr = ''(avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 20 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "10m";
        labels = {
          alertclass = "iowait";
          severity = "warning";
        };
        annotations = {
          summary = "High CPU iowait (instance {{ $labels.instance }})";
          description = ''
            CPU iowait is > 20%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorCritIoWait";
        expr = ''(avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 40 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "10m";
        labels = {
          alertclass = "iowait";
          severity = "critical";
        };
        annotations = {
          summary = "Critical CPU iowait (instance {{ $labels.instance }})";
          description = ''
            CPU iowait is > 40%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorFatalIoWait";
        expr = ''(avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 50 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "20m";
        labels = {
          alertclass = "iowait";
          severity = "critical";
        };
        annotations = {
          summary = "Critical CPU iowait (instance {{ $labels.instance }})";
          description = ''
            CPU iowait is > 50%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "StorageHighCpuLoad";
        expr = ''100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="storage"}[5m])) * 100) > 80'';
        for = "15m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High CPU load (instance {{ $labels.instance }})";
          description = ''
            CPU load is > 80%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "StorageHighIoWait";
        expr = ''(avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="storage"}[5m])) * 100) > 30'';
        for = "15m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "High CPU iowait (instance {{ $labels.instance }})";
          description = ''
            CPU iowait is > 30%

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorLowZfsArcC";
        expr = ''node_zfs_arc_c{role="hypervisor"} < (node_memory_MemTotal_bytes / 8) and on(instance) (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 10'';
        for = "5m";
        labels = {
          severity = "warning";
        };
        annotations = {
          summary = "ZFS arc_c too low (instance {{ $labels.instance }})";
          description = ''
            ZFS arc_c is too low (less than 1/8 of total memory)

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorHighArcMetaUsed";
        expr = ''node_zfs_arc_arc_meta_used{role="hypervisor"} / node_zfs_arc_size * 100 > 80 and on(instance) (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 10'';
        for = "5m";
        labels = {
          alertclass = "arcmetaused";
          severity = "warning";
        };
        annotations = {
          summary = "ZFS arc_meta_used uses too much of arc_size (instance {{ $labels.instance }})";
          description = ''
            ZFS arc_meta_used uses more than 80% of arc_size

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorCritArcMetaUsed";
        expr = ''node_zfs_arc_arc_meta_used{role="hypervisor"} / node_zfs_arc_size * 100 > 90 and on(instance) (avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 20'';
        for = "10m";
        labels = {
          alertclass = "arcmetaused";
          severity = "critical";
        };
        annotations = {
          summary = "ZFS arc_meta_used uses too much of arc_size (instance {{ $labels.instance }})";
          description = ''
            ZFS arc_meta_used uses more than 90% of arc_size

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeHighLoad";
        expr = ''node_load5{job="nodes"} > 300 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "5m";
        labels = {
          alertclass = "loadavg";
          severity = "warning";
        };
        annotations = {
          summary = "Load average too high (instance {{ $labels.instance }})";
          description = ''
            5 minute load average is too high

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeCritLoad";
        expr = ''node_load5{job="nodes"} > 1000'';
        for = "5m";
        labels = {
          alertclass = "loadavg";
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "Load average critical (instance {{ $labels.instance }})";
          description = ''
            5 minute load average is too high

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeFatalLoad";
        expr = ''node_load5{job="nodes"} > 2000'';
        for = "5m";
        labels = {
          alertclass = "loadavg";
          severity = "fatal";
          frequency = "hourly";
        };
        annotations = {
          summary = "Load average critical (instance {{ $labels.instance }})";
          description = ''
            5 minute load average is too high

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NoOsctlPoolImported";
        expr = ''osctl_pool_count{job="nodes",role="hypervisor",state="active"} == 0'';
        for = "15m";
        labels = {
          severity = "fatal";
          frequency = "10m";
        };
        annotations = {
          summary = "No osctl pool in use (instance {{ $labels.instance }})";
          description = ''
            No osctl pool is imported into osctld

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }

  {
    name = "nodes-ping";
    interval = "15s";
    rules = [
      {
        alert = "PingExporterDown";
        expr = ''up{job="nodes-ping"} == 0'';
        for = "5m";
        labels = {
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "Ping exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check node availability

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeDown";
        expr = ''probe_success{job="nodes-ping"} == 0'';
        for = "30s";
        labels = {
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "Node is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeHighPing";
        expr = ''probe_duration_seconds{job="nodes-ping"} >= 1 and on(job, instance) probe_success == 1'';
        for = "1m";
        labels = {
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Node is slow to respond (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} takes more than a second to ping

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
