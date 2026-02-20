[
  {
    name = "nodes";
    interval = "20s";
    rules = [
      {
        alert = "NodeExporterDown";
        expr = ''up{job="nodes"} == 0'';
        for = "1m";
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
        alert = "HypervisorEmpty";
        expr = ''osctl_pool_containers_count{role="hypervisor",state="running"} == 0'';
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
        alert = "HypervisorNearlyEmpty";
        expr = ''osctl_pool_containers_count{role="hypervisor",state="running"} <= 10'';
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
        alert = "HypervisorCritOsCpuLoad";
        expr = ''100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle",role="hypervisor",os="vpsadminos"}[5m])) * 100) > 90 and on(instance) time() - node_boot_time_seconds > 3600'';
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
        alert = "HypervisorLongHighIoWait";
        expr = ''(avg by(instance) (irate(node_cpu_seconds_total{mode="iowait",role="hypervisor"}[5m])) * 100) > 10 and on(instance) time() - node_boot_time_seconds > 3600'';
        for = "6h";
        labels = {
          alertclass = "iowait";
          severity = "warning";
        };
        annotations = {
          summary = "Long-term high CPU iowait (instance {{ $labels.instance }})";
          description = ''
            CPU iowait is > 10% for too long

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
        alert = "NodeHighTxgCount";
        expr = ''rate(zpool_txgs_count{job="nodes"}[5m]) * 60 >= 20'';
        for = "2m";
        labels = {
          alertclass = "txgcount";
          severity = "warning";
        };
        annotations = {
          summary = "ZFS high TXG count per minute (instance {{ $labels.instance }})";
          description = ''
            ZFS makes more than 20 TXGs per minute

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeCritNoTxgs";
        expr = ''rate(zpool_txgs_count{job="nodes",role="hypervisor"}[5m]) * 180 < 1'';
        for = "1m";
        labels = {
          alertclass = "nodenotxgs";
          severity = "critical";
          frequency = "2m";
        };
        annotations = {
          summary = "ZFS not making TXGs (instance {{ $labels.instance }})";
          description = ''
            ZFS made less than 1 TXG in three minutes

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeFatalNoTxgs";
        expr = ''rate(zpool_txgs_count{job="nodes",role="hypervisor"}[2m]) * 240 < 1'';
        for = "1m";
        labels = {
          alertclass = "nodenotxgs";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "ZFS not making TXGs (instance {{ $labels.instance }})";
          description = ''
            ZFS made less than 1 TXG in four minutes

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "StorageCritNoTxgs";
        expr = ''rate(zpool_txgs_count{job="nodes",role="storage"}[5m]) * 240 < 1'';
        for = "1m";
        labels = {
          alertclass = "storagenotxgs";
          severity = "critical";
          frequency = "2m";
        };
        annotations = {
          summary = "ZFS not making TXGs (instance {{ $labels.instance }})";
          description = ''
            ZFS made less than 1 TXG in four minutes

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "StorageFatalNoTxgs";
        expr = ''rate(zpool_txgs_count{job="nodes",role="storage"}[5m]) * 1800 < 1'';
        for = "1m";
        labels = {
          alertclass = "storagenotxgs";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "ZFS not making TXGs (instance {{ $labels.instance }})";
          description = ''
            ZFS made less than 1 TXG in 30 minutes

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorFatalNoSsdWrites";
        expr = ''sum by (alias,fqdn) (increase(node_disk_written_bytes_total{job="nodes",role="hypervisor",storage_type=~"hdd|ssd",device=~"sd.+"}[1m])) == 0'';
        labels = {
          alertclass = "nowrites";
          alertwhen = "inuse";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "Block devices not showing any writes (instance {{ $labels.instance }})";
          description = ''
            Block devices not showing any writes

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "HypervisorFatalNoNvmeWrites";
        expr = ''sum by (alias,fqdn) (increase(node_disk_written_bytes_total{job="nodes",role="hypervisor",storage_type="nvme",device=~"nvme.+"}[1m])) == 0'';
        labels = {
          alertclass = "nowrites";
          alertwhen = "inuse";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "Block devices not showing any writes (instance {{ $labels.instance }})";
          description = ''
            Block devices not showing any writes

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeFatalRootfsFreeSpace";
        expr = ''(node_filesystem_avail_bytes{job="nodes",mountpoint="/"} / node_filesystem_size_bytes) * 100 <= 5'';
        for = "5m";
        labels = {
          alertclass = "fsavail";
          severity = "fatal";
          frequency = "5m";
        };
        annotations = {
          summary = "Not enough free space on rootfs (instance {{ $labels.instance }})";
          description = ''
            Rootfs uses more than 95% of available space

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
        alert = "NodeOverallCritLoad";
        expr = "node_load1 - on (fqdn) group_left() sum by (fqdn) (topk by (fqdn)(5, osctl_container_load1)) > 400";
        for = "5m";
        labels = {
          alertclass = "loadavg";
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Overall load average critical (instance {{ $labels.instance }})";
          description = ''
            Overall load average (excluding top 5 VPS) is critical

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeCritUninterruptibleProcesses";
        expr = ''node_processes_state{job="nodes",state="D"} > 1000 and on(instance) time() - node_boot_time_seconds > 1800'';
        for = "1m";
        labels = {
          alertclass = "processes_d";
          severity = "critical";
        };
        annotations = {
          summary = "Too many uninterruptible (D) processes (instance {{ $labels.instance }})";
          description = ''
            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeFatalUninterruptibleProcesses";
        expr = ''node_processes_state{job="nodes",state="D"} > 2400 and on(instance) time() - node_boot_time_seconds > 1800'';
        for = "1m";
        labels = {
          alertclass = "processes_d";
          severity = "fatal";
        };
        annotations = {
          summary = "Too many uninterruptible (D) processes (instance {{ $labels.instance }})";
          description = ''
            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeWarnZombieProcesses";
        expr = ''node_processes_state{job="nodes",state="Z"} > 10000'';
        for = "5m";
        labels = {
          alertclass = "processes_z";
          severity = "warning";
          frequency = "6h";
        };
        annotations = {
          summary = "Node has too many zombie processes (instance {{ $labels.instance }})";
          description = ''
            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsWarnUninterruptibleProcesses";
        expr = ''count by (fqdn) (osctl_container_processes_state{state="D"} > 5) > 5 and on(fqdn) time() - node_boot_time_seconds > 1800'';
        for = "1m";
        labels = {
          alertclass = "vps_processes_d";
          severity = "warning";
        };
        annotations = {
          summary = "Too many VPS with uninterruptible (D) processes (instance {{ $labels.instance }})";
          description = ''
            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsWarnZombieProcesses";
        expr = ''osctl_container_processes_state{state="Z"} > 10000'';
        for = "5m";
        labels = {
          alertclass = "vps_processes_z";
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "VPS has too many zombie processes (instance {{ $labels.instance }})";
          description = ''
            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "SshExporterDown";
        expr = ''up{job="ssh-exporters"} == 0'';
        for = "5m";
        labels = {
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "SSH exporter is down (instance {{ $labels.instance }})";
          description = ''
            SSH exporter is down, node SSH checks are not working.

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeSshDownCrit";
        expr = ''ssh_host_up{job="ssh-exporters"} == 0'';
        for = "10m";
        labels = {
          alertclass = "sshdown";
          severity = "critical";
          frequency = "2m";
        };
        annotations = {
          summary = "Node not responding over SSH (instance {{ $labels.instance }})";
          description = ''
            Node is not responding over SSH

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeSshDownFatal";
        expr = ''ssh_host_up{job="ssh-exporters"} == 0'';
        for = "15m";
        labels = {
          alertclass = "sshdown";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "Node not responding over SSH (instance {{ $labels.instance }})";
          description = ''
            Node is not responding over SSH

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeSshLoginWarn";
        expr = ''ssh_host_check_seconds{job="ssh-exporters"} > 10'';
        labels = {
          alertclass = "sshtime";
          severity = "warning";
          frequency = "1h";
        };
        annotations = {
          summary = "Node SSH login takes too long (instance {{ $labels.instance }})";
          description = ''
            Node SSH login takes too long

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeSshLoginCrit";
        expr = ''ssh_host_check_seconds{job="ssh-exporters"} >= 30'';
        for = "2m";
        labels = {
          alertclass = "sshtime";
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Node SSH login takes too long (instance {{ $labels.instance }})";
          description = ''
            Node SSH login takes too long

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeSshCritLoad";
        expr = ''up{job="nodes"} == 0 and on (fqdn) ssh_host_load1 > 1000'';
        for = "5m";
        labels = {
          alertclass = "sshload";
          severity = "critical";
          frequency = "5m";
        };
        annotations = {
          summary = "Node loadavg is too high (instance {{ $labels.instance }})";
          description = ''
            Node load average fetched over SSH is too high

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeSshFatalLoad";
        expr = ''up{job="nodes"} == 0 and on (fqdn) ssh_host_load1 > 2000'';
        for = "5m";
        labels = {
          alertclass = "sshload";
          severity = "fatal";
          frequency = "5m";
        };
        annotations = {
          summary = "Node loadavg is too high (instance {{ $labels.instance }})";
          description = ''
            Node load average fetched over SSH is too high

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelPtyWarn";
        expr = "sysctl_kernel_pty_nr >= 6*600*2";
        for = "5m";
        labels = {
          alertclass = "pty_nr";
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "High PTY count (instance {{ $labels.instance }})";
          description = ''
            More than 4096 allocated PTYs. In general, 6 PTYs are needed for 1 VPS.

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelPtyCrit";
        expr = "sysctl_kernel_pty_max - sysctl_kernel_pty_reserve - sysctl_kernel_pty_nr <= 1024";
        for = "5m";
        labels = {
          alertclass = "pty_nr";
          severity = "critical";
          frequency = "hourly";
        };
        annotations = {
          summary = "Critical PTY count (instance {{ $labels.instance }})";
          description = ''
            Less than 1024 PTYs are available for container use.

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NfConntrackEntriesHigh";
        expr = ''node_nf_conntrack_entries{role="hypervisor"} / node_nf_conntrack_entries_limit * 100 > 80'';
        for = "5m";
        labels = {
          alertclass = "nfconntrackentries";
          severity = "warning";
          frequency = "1h";
        };
        annotations = {
          summary = "nf conntrack entries too high (instance {{ $labels.instance }})";
          description = ''
            Netfilter conntrack table is more than 80% full

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeOsctldDown";
        expr = ''osctld_up{job="nodes"} == 0 or on(instance) osctld_responsive == 0 or on(instance) osctld_initialized == 0'';
        for = "5m";
        labels = {
          alertclass = "osctld";
          severity = "critical";
          frequency = "5m";
        };
        annotations = {
          summary = "osctld down (instance {{ $labels.instance }})";
          description = ''
            osctld is down or not operational

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

      {
        alert = "VpsNoRefquotaSet";
        expr = ''osctl_container_dataset_refquota_bytes{job="nodes"} == 0'';
        for = "12h";
        labels = {
          alertclass = "vpsquota";
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "VPS has no refquota set (instance {{ $labels.instance }})";
          description = ''
            VPS has no refquota set

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsStartingTooLong";
        expr = ''osctl_container_state_starting{job="nodes"} == 1'';
        for = "15m";
        labels = {
          alertclass = "vpsstate";
          severity = "critical";
          frequency = "15m";
        };
        annotations = {
          summary = "VPS is taking too long to start (instance {{ $labels.instance }})";
          description = ''
            VPS is taking too long to start

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsAborting";
        expr = ''osctl_container_state_aborting{job="nodes"} == 1'';
        for = "15m";
        labels = {
          alertclass = "vpsstate";
          severity = "critical";
          frequency = "15m";
        };
        annotations = {
          summary = "VPS is taking too long to abort (instance {{ $labels.instance }})";
          description = ''
            VPS is taking too long to abort

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsError";
        expr = ''osctl_container_state_aborting{job="nodes"} == 1'';
        for = "5m";
        labels = {
          alertclass = "vpsstate";
          severity = "critical";
          frequency = "15m";
        };
        annotations = {
          summary = "VPS is in an error state (instance {{ $labels.instance }})";
          description = ''
            VPS is in an error state

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "VpsFrozen";
        expr = ''osctl_container_state_freezing{job="nodes"} == 1 or on(instance) osctl_container_state_frozen == 1'';
        for = "10m";
        labels = {
          alertclass = "vpsstate";
          severity = "critical";
          frequency = "15m";
        };
        annotations = {
          summary = "VPS is in an error state (instance {{ $labels.instance }})";
          description = ''
            VPS is in an error state

            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "PacketLoss";
        expr = ''rate(node_network_transmit_drop_total{device=~"(teng.+)|(oneg.+)"}[5m]) > 0 or rate(node_network_receive_drop_total{device=~"(teng.+)|(oneg.+)"}[5m]) > 0'';
        for = "10m";
        labels = {
          alertclass = "packetloss";
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "Packet loss detected (instance {{ $labels.instance }})";
          description = ''
            VALUE = {{ $value }}
            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }

  {
    name = "nodes-ping-host";
    interval = "15s";
    rules = [
      {
        alert = "PingHostExporterDown";
        expr = ''up{job="nodes-ping-host"} == 0'';
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
        alert = "NodeOfflineCritical";
        expr = ''probe_success{job="nodes-ping-host"} == 0'';
        for = "30s";
        labels = {
          alertclass = "nodeoffline";
          severity = "critical";
          frequency = "2m";
        };
        annotations = {
          summary = "Node is offline (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeOfflineFatal";
        expr = ''probe_success{job="nodes-ping-host"} == 0'';
        for = "90s";
        labels = {
          alertclass = "nodeoffline";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "Node is offline (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeHighPing";
        expr = ''probe_duration_seconds{job="nodes-ping-host"} >= 1 and on(job, instance) probe_success == 1'';
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

  {
    name = "nodes-ping-netif";
    interval = "15s";
    rules = [
      {
        alert = "PingNetifExporterDown";
        expr = ''up{job="nodes-ping-netif"} == 0'';
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
        alert = "NodeNetifDown";
        expr = ''probe_success{job="nodes-ping-netif"} == 0'';
        for = "30s";
        labels = {
          alertclass = "nodenetifdown";
          severity = "critical";
          frequency = "10m";
        };
        annotations = {
          summary = "Node network interface is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping on {{ $labels.network_interface }} ({{ $labels.ip_address }})

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeDownCritical";
        expr = ''max by (fqdn) (probe_success{job="nodes-ping-netif"}) == 0'';
        for = "30s";
        labels = {
          alertclass = "nodedown";
          severity = "critical";
          frequency = "2m";
        };
        annotations = {
          summary = "Node is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping on any network interface

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeDownFatal";
        expr = ''max by (fqdn) (probe_success{job="nodes-ping-netif"}) == 0'';
        for = "90s";
        labels = {
          alertclass = "nodedown";
          severity = "fatal";
          frequency = "2m";
        };
        annotations = {
          summary = "Node is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping on any network interface

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }

  {
    name = "nodes-mgmt-ping";
    interval = "30s";
    rules = [
      {
        alert = "PingMgmtExporterDown";
        expr = ''up{job="nodes-mgmt-ping"} == 0'';
        for = "5m";
        labels = {
          severity = "warning";
          frequency = "hourly";
        };
        annotations = {
          summary = "Management ping exporter is down (instance {{ $labels.instance }})";
          description = ''
            Unable to check node management availability

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "NodeMgmtDown";
        expr = ''probe_success{job="nodes-mgmt-ping"} == 0'';
        for = "120s";
        labels = {
          severity = "warning";
          frequency = "15m";
        };
        annotations = {
          summary = "Node management is down (instance {{ $labels.instance }})";
          description = ''
            {{ $labels.instance }} does not respond to ping

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
