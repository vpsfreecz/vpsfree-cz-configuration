def ensure_vpsfree_oom_event_route!(user)
  user.with_lock do
    existing = EventRoute.active.find_by(
      user: user,
      parent_id: nil,
      label: 'OOM report notifications',
      event_type: 'vps.oom_report',
      event_type_pattern: nil,
      subject_scope: EventRoute.subject_scopes.fetch('self')
    )
    next existing if existing

    NotificationReceiver.ensure_defaults_for!(user)
    receiver = EventRoute.default_admin_route_for(user)&.notification_receiver
    raise 'default administrator notification receiver is missing' unless receiver

    user.event_routes.create!(
      notification_receiver: receiver,
      label: 'OOM report notifications',
      position: EventRoute.prepend_position_for(user),
      event_type: 'vps.oom_report',
      grouping_enabled: true,
      group_by: ['vps_id'],
      group_wait_seconds: 60,
      group_interval_seconds: 3 * 60 * 60
    )
  end
end
