[
  {
    name = "kernel-livepatches";
    rules = [
      {
        alert = "BpfLivepatchProgramMissing";
        expr = ''kernel_bpf_program_required{job="nodes"} unless on(instance, program) (kernel_bpf_program_loaded{job="nodes"} == 1)'';
        for = "5m";
        labels = {
          alertclass = "kernel_livepatch";
          severity = "fatal";
          frequency = "5m";
        };
        annotations = {
          summary = "Required BPF livepatch program is not loaded (instance {{ $labels.instance }})";
          description = ''
            Required BPF livepatch program {{ $labels.program }} is not attached

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelLivepatchMissing";
        expr = ''kernel_livepatch_required{job="nodes"} unless on(instance, module) (kernel_livepatch_loaded{job="nodes"} == 1)'';
        for = "5m";
        labels = {
          alertclass = "kernel_livepatch";
          severity = "fatal";
          frequency = "5m";
        };
        annotations = {
          summary = "Required kernel livepatch is not loaded (instance {{ $labels.instance }})";
          description = ''
            Required kernel livepatch {{ $labels.module }} is not enabled

            LABELS: {{ $labels }}
          '';
        };
      }

      {
        alert = "KernelProtectionMonitoringFailed";
        expr = ''kernel_protection_monitoring_success{job="nodes"} == 0'';
        for = "5m";
        labels = {
          alertclass = "kernel_livepatch";
          severity = "critical";
          frequency = "5m";
        };
        annotations = {
          summary = "Kernel protection monitoring failed (instance {{ $labels.instance }})";
          description = ''
            Kernel protection monitoring failed for {{ $labels.component }}

            LABELS: {{ $labels }}
          '';
        };
      }
    ];
  }
]
