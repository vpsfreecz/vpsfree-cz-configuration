IncidentEscalation.configure do
  rule :oomd, adapter: :node_oomd do
    labels en: 'VPS memory-pressure incidents', cs: 'Incidenty přetížení paměti VPS'
    templates warning: :vps_memory_pressure_warning,
              stopped: :vps_memory_pressure_stopped

    policy do |ctx|
      {
        warning_limit: 5,
        stop_limit: 10,
        mode: ctx.global_mode,
        suppress_actions: false,
        reason: 'standard_memory_pressure'
      }
    end
  end
end
