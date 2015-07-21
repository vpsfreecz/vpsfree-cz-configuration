DatasetInPool.connect_hook(:create) do |ret, dataset_in_pool|

  # Create a dataset for backups
  if dataset_in_pool.pool.role == 'hypervisor'
    puts "\n\nCREATE BACKUP DATASET FOR #{dataset_in_pool.dataset.full_name}\n\n"

    backup_pool = Pool.backup.take!

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
    production = ::Environment.find_by!(label: 'Production')

    if dataset_in_pool.pool.node.environment_id == production.id
      VpsAdmin::API::DatasetPlans.plans[:daily_backup].register(dataset_in_pool)
      VpsAdmin::API::DatasetPlans.confirm
    end
  end

  ret
end

Vps.connect_hook(:create) do |ret, vps|

  # Nothing to do here as of yet
  ret

end

User.connect_hook(:create) do |ret, user|

  # Create NAS dataset
  ds = ::Dataset.new(
      name: user.id.to_s,
      user: user,
      user_editable: false,
      user_create: true,
      user_destroy: true,
      confirmed: ::Dataset.confirmed(:confirm_create)
  )

  dip = use_chain(TransactionChains::Dataset::Create, args: [
      ::Pool.primary.take!,
      nil,
      [ds],
      false,
      {quota: 250*1024},
      user,
      'nas'
  ]).last
 
  ret
end
