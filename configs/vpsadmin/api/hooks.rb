DatasetInPool.connect_hook(:create) do |ret, dataset_in_pool|

  # Create a dataset for backups
  if dataset_in_pool.pool.role == 'hypervisor'
    puts "\n\nCREATE BACKUP DATASET FOR #{dataset_in_pool.dataset.full_name}\n\n"

    backup_pool = Pool.backup.take!

    dataset_in_pool.update!(
        min_snapshots: 1,
        max_snapshots: 1
    )

    begin
      backup = DatasetInPool.create(
          dataset: dataset_in_pool.dataset,
          pool: backup_pool
      )

      append(Transactions::Storage::CreateDataset, args: backup) do
        create(backup)
      end

    rescue ActiveRecord::RecordNotUnique
      # Backup dataset already exists, we don't have to create it,
      # just recreate backup actions
      backup = DatasetInPool.find_by!(
          dataset: dataset_in_pool.dataset,
          pool: backup_pool
      )
    end

    # Add backup plan only for datasets in production environment
    backup_envs = %w(Production Playground Staging).map do |v|
      ::Environment.find_by!(label: v).id
    end

    if backup_envs.include?(dataset_in_pool.pool.node.location.environment_id)
      VpsAdmin::API::DatasetPlans.plans[:daily_backup].register(dataset_in_pool)
    end
  end

  ret
end

DatasetInPool.connect_hook(:migrated) do |ret, from, to|

  # When migrating dataset from playground to production and the dataset
  # does not already have plan daily_backup, add it.
  if from.pool.node.location.environment.label == 'Playground' \
     && to.pool.node.location.environment.label == 'Production' \
     && !from.dataset_in_pool_plans.joins(
             environment_dataset_plan: [:dataset_plan]
         ).exists?(dataset_plans: {name: :daily_backup})
    append(Transactions::Utils::NoOp, args: find_node_id) do
      VpsAdmin::API::DatasetPlans.plans[:daily_backup].register(
          to,
          confirmation: self
      )
    end
  end

  ret
end

Vps.connect_hook(:create) do |ret, vps|

  # Nothing to do here as of yet
  ret

end

def get_netif_shaper_limit(netif)
  if netif.vps_id
    location = netif.vps.node.location
  else
    return nil
  end

  limit =
    case location.label
    when 'Praha', 'Playground', 'Staging'
      300 * 1024 * 1024
    when 'Brno'
      300 * 1024 * 1024
    else
      fail "Unsupported location #{location.inspect}"
    end

  [limit, limit]
end

def set_netif_shaper_limit(netif)
  max_tx, max_rx = get_netif_shaper_limit(netif)
  return if max_tx.nil?

  netif.update!(max_tx: max_tx, max_rx: max_rx)
end

NetworkInterface.connect_hook(:create) do |ret, netif|

  set_netif_shaper_limit(netif)
  ret

end

NetworkInterface.connect_hook(:morph) do |ret, netif, original_kind, target_kind|

  if target_kind == 'veth_routed'
    max_tx, max_rx = get_netif_shaper_limit(netif)

    if max_tx
      append_t(
        Transactions::NetworkInterface::SetShaper,
        args: [netif],
        kwargs: {
          max_tx: max_tx,
          max_rx: max_rx,
      }) do |t|
        t.edit(netif, max_tx: max_tx, max_rx: max_rx)
      end
    end
  end

  ret

end

NetworkInterface.connect_hook(:clone) do |ret, src_netif, dst_netif|

  if src_netif.vps.node.location != dst_netif.vps.node.location
    max_tx, max_rx = get_netif_shaper_limit(dst_netif)

    if max_tx && (max_tx != dst_netif.max_tx || max_rx != dst_netif.max_rx)
      append_t(
        Transactions::NetworkInterface::SetShaper,
        args: [dst_netif],
        kwargs: {
          max_tx: max_tx,
          max_rx: max_rx,
      }) do |t|
        t.edit(dst_netif, max_tx: max_tx, max_rx: max_rx)
      end
    end
  end

  ret

end

User.connect_hook(:create) do |ret, user|

  if user.object_state == 'active'
    # Set expiration_date to now - 4 days. The grace period for suspending
    # users is 14 days, so new users will be suspended after 10 days.
    user.update!(expiration_date: Time.now - 4 * 24 * 60 * 60)
  elsif user.object_state == 'suspended'
    # Give the user 10 days to pay
    append_t(Transactions::Utils::NoOp, args: find_node_id) do |t|
      t.edit(user, expiration_date: Time.now + 10 * 24 * 60 * 60)
      t.edit(user.current_object_state, reason: 'Waiting for payment of the membership fee')
    end
  end

  # Create NAS dataset
  ds = ::Dataset.new(
      name: user.id.to_s,
      user: user,
      user_editable: false,
      user_create: true,
      user_destroy: false,
      confirmed: ::Dataset.confirmed(:confirm_create)
  )

  dip = use_chain(TransactionChains::Dataset::Create, args: [
      ::Pool.primary.take!,
      nil,
      [ds],
      automount: false,
      properties: {quota: 250*1024},
      user: user,
      label: 'nas',
  ]).last

  # Assign user namespace block 8 * 65k uids
  uns = use_chain(TransactionChains::UserNamespace::Allocate, args: [user, 8])

  # Create default user namespace mapping
  uns_map = UserNamespaceMap.create_chained!(uns, 'Default map')

  append_t(Transactions::Utils::NoOp, args: find_node_id) do |t|
    t.just_create(uns_map)
    t.edit_before(uns_map.user_namespace_map_ugid, user_namespace_map_id: nil)

    UserNamespaceMapEntry.kinds.each_value do |kind|
      t.just_create(UserNamespaceMapEntry.create!(
        user_namespace_map: uns_map,
        kind: kind,
        vps_id: 0,
        ns_id: 0,
        count: uns.size,
      ))
    end
  end
 
  ret
end
