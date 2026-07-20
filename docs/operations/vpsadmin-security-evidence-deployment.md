# Deploying the vpsAdmin evidence compatibility cleanup

This runbook deploys the cleanup release that removes two temporary
compatibility paths from vpsAdmin:

- normalization of the old `vpsfree_cz_configuration` software component; and
- runtime repair of boot events written by old supervisors during the previous
  rolling deployment.

The preceding boot-evidence release at
`1bca29dfac3dba6a82a857ffad24d42e46ae861e` must already be deployed to every
reporting Node and supervisor. Its history backfill must already be complete.
Do not use this runbook until that premise has been verified.

## Compatibility

This is an application-only cleanup. It does not change the database schema,
evidence schema version, API response values, stored enum values, vpsAdminOS,
or required Node status fields. It requires no Node reboot, history
reconstruction, or data migration.

Canonical reporters already emit `system_configuration`. The API continues to
store that component as enum value `3`, and the WebUI continues to label it
System configuration and link configured revisions to the
`vpsfree-cz-configuration` repository. Only the obsolete spelling and its
WebUI alias are removed.

Migration `20260720120000 ReconcileReportedBootEvidence` remains part of the
migration history and must already report `up`. Do not rerun it or mark it
down. Its corrected data remains valid. The supported first evidence report
still merges one matching reconstructed boot, so a Node that has never
reported evidence is unaffected by this cleanup.

Old and cleanup application processes can run together after the safety gate
below passes: both accept canonical reports and read the same stored values.
Rolling back to the preceding release restores both compatibility paths and
requires no database action.

A missed old reporter is intentionally unsupported after this deployment. A
report containing `vpsfree_cz_configuration` is retained as an invalid current
evidence snapshot, and no kernel evidence events are derived from it. Ordinary
Node status and system-state processing continue. Treat such a gap as a
deployment error and update the reporter; do not add the alias back locally.

## Prepare the reviewed revision

The configuration channels must all pin the exact reviewed vpsAdmin revision:

```shell
VPSADMIN_REVISION=1bb84ae9bc792eef5650a030f850409c737b6a91
```

Before building, obtain the exact configuration commit approved for rollout
through the normal change-review channel. Set
`APPROVED_CONFIGURATION_REVISION` to that out-of-band value; do not derive it
from the worktree being checked. Then verify the tracked worktree and pins:

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT
VPSADMIN_REVISION=1bb84ae9bc792eef5650a030f850409c737b6a91

test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
test "$(jq -r '.nodes.vpsadminStaging.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminServices.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminProduction.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
confctl inputs channel ls vpsadmin
confctl inputs channel ls staging
confctl inputs channel ls production
```

The application hosts use `vpsadminServices`. Staging and production Nodes use
`vpsadminStaging` and `vpsadminProduction`; those two pins prepare later Node
deployments but do not deploy a Node as part of this procedure.

## Run the safety gate

First confirm from a current `vpsadmin-api-shell` that migration
`20260720120000 Reconcile reported boot evidence` reports `up`:

```shell
bundle exec rake db:migrate:status
```

Then run the following read-only check from the API console. It requires every
active Node/storage reporter to have a recent valid snapshot from the fully
deployed preceding revision. It also verifies that directly reported boot
times and confidence match their immutable evidence and that no reconstructed
bootstrap candidate remains beside a first reported boot.

```ruby
required_reporter_revision = '1bca29dfac3dba6a82a857ffad24d42e46ae861e'
cutoff = 10.minutes.ago
roles = %w[node storage].map { |role| Node.roles.fetch(role) }
reporter_issues = []

Node.where(active: true, role: roles)
    .includes(node_current_status: { kernel_evidence: :software_versions })
    .find_each do |node|
  status = node.node_current_status
  evidence = status&.kernel_evidence
  versions = evidence&.software_versions&.index_by do |version|
    [version.generation, version.component]
  end || {}
  reporter = versions[['current', 'vpsadmin']]
  configurations = %w[booted current].map do |generation|
    versions[[generation, 'system_configuration']]
  end

  reasons = []
  reasons << 'status is stale or missing' if status&.updated_at.nil? ||
                                                status.updated_at < cutoff
  reasons << 'current evidence is missing' unless evidence
  reasons << 'reporter revision is not the deployed canonical reporter' unless
    reporter&.revision == required_reporter_revision
  reasons << 'canonical system configuration evidence is missing' if
    configurations.any?(&:nil?)
  reporter_issues << [node.id, node.name, reasons] if reasons.any?
end

reported_issues = []
NodeKernelEvent.boot.node_report
               .includes(kernel_evidence: :kernel_evidence_errors)
               .find_each do |event|
  evidence = event.kernel_evidence
  estimated = evidence&.kernel_evidence_errors&.any? do |error|
    error.component == 'booted_at' &&
      error.reason == 'estimated_from_uptime'
  end
  expected_confidence = if evidence&.booted_at.nil?
                          'incomplete'
                        elsif estimated
                          'inferred'
                        else
                          'exact'
                        end
  effective_time_matches = if evidence&.booted_at
                             event.effective_at == evidence.booted_at
                           else
                             event.effective_at.nil?
                           end

  unless evidence&.event? && effective_time_matches &&
         event.confidence == expected_confidence
    reported_issues << event.id
  end
end

duplicate_issues = []
NodeKernelEvent.boot.node_report.where(observed_after: nil).find_each do |event|
  booted_at = event.booted_at || event.effective_at
  next unless booted_at && event.booted_release

  candidates = NodeKernelEvent.boot.reconstructed_node_status
                              .where(node_id: event.node_id)
                              .where(booted_release: event.booted_release)
                              .where(booted_at: (booted_at - 5.minutes)..
                                                (booted_at + 5.minutes))
                              .where('observed_before <= ?', event.observed_before)
                              .pluck(:id)
  duplicate_issues << [event.id, candidates] if candidates.any?
end

puts "reporter issues: #{reporter_issues.inspect}"
puts "reported boot issues: #{reported_issues.inspect}"
puts "duplicate candidates: #{duplicate_issues.inspect}"
abort 'evidence compatibility cleanup gate failed' unless
  reporter_issues.empty? && reported_issues.empty? && duplicate_issues.empty?
```

All three collections must be empty. Stop the rollout and investigate any
entry. Do not repair production rows by hand merely to make the gate pass.

## Build and deploy the application

Build all application hosts before the maintenance window:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
```

Confirm that normal API and WebUI rollback generations are available. No
database backup beyond the normal deployment policy is required because this
release has no migration or data write outside ordinary status processing.

Immediately before the first deployment, verify the actual running supervisor
service on both API hosts. The service must be healthy and its process working
directory must contain the preceding compatible revision. This checks the
running process, not the configured channel or a built but inactive generation:

```shell
EXPECTED_SUPERVISOR_REVISION=1bca29dfac3dba6a82a857ffad24d42e46ae861e

confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  sh -ceu '
    expected="$1"
    systemctl is-active --quiet vpsadmin-supervisor
    pid="$(systemctl show --property MainPID --value vpsadmin-supervisor)"
    test "$pid" -gt 0
    test "$(cat "/proc/$pid/cwd/.git-revision")" = "$expected"
  ' sh "$EXPECTED_SUPERVISOR_REVISION"
```

`confctl ssh` must exit successfully for both `int.api1` and `int.api2`. Stop
if either service is inactive, has no main process, or reports another
revision. Do not begin the rolling deployment while an old supervisor can
still write events that the cleanup release no longer repairs.

Deploy the WebUI hosts one at a time:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.webui1 switch
confctl deploy cz.vpsfree/vpsadmin/int.webui2 switch
```

The currently deployed API already returns canonical component values, so the
System configuration row and GitHub link must remain visible after each
frontend switch.

Deploy api1, verify API and supervisor health, and wait for several ordinary
Node status intervals before deploying api2:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api1 switch
confctl deploy cz.vpsfree/vpsadmin/int.api2 switch
```

Do not run `db:migrate` or any history reconstruction task for this release.
No deployment of `int.vpsadmin1` is required: its mailer-role nodectld does not
report host-kernel evidence.

## Verify the cleanup

After both API hosts have consumed several status intervals:

- confirm API and supervisor logs contain no invalid
  `software_versions.component` evidence errors;
- rerun the safety gate and confirm all collections remain empty;
- inspect `node1.stg`, `node2.stg`, and at least one production Node in both
  WebUI frontends;
- confirm Software versions still shows System configuration and links its
  revision to the configured `vpsfree-cz-configuration` commit;
- confirm Kernel history retains the corrected boot times and precision;
- confirm no duplicate current kernel-history row appears; and
- confirm ordinary Node status and system-state timelines continue advancing.

Do not deploy or reboot Nodes solely for this verification. The staging and
production channel pins take effect through the normal later Node rollout.

## Rollback

Switch api2 and api1 back to their previous system generations, then switch the
WebUI hosts back. The preceding release accepts canonical reports, reads all
stored values written by the cleanup release, and restores both temporary
compatibility paths. No migration, data restoration, history reconstruction,
or Node rollback is required.

The staging and production input pins do not change a running Node. They may
remain at the cleanup revision while the application rollback is investigated,
or be reverted through a separately reviewed configuration change before a
later Node deployment.
