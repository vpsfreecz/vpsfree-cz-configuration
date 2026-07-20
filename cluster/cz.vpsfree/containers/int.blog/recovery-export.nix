{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.vpsfree.blog.recovery;
  siteName = "blog.vpsfree.cz";
  databaseName = "wordpress";
  uploadsRoot = "/var/lib/wordpress/${siteName}/uploads";
  stateDirectory = "wordpress-backup";
  stateRoot = "/var/lib/${stateDirectory}";
  backupRoot = "${stateRoot}/${siteName}";
  generationsRoot = "${backupRoot}/generations";
  acceptedRoot = "${backupRoot}/accepted";
  currentLink = "${backupRoot}/current";
  configuredFirstExpectedDate = if cfg.firstExpectedDate == null then "" else cfg.firstExpectedDate;

  exporterRuntimeInputs = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
    pkgs.util-linux
    config.services.mysql.package
  ];

  recoveryExport = pkgs.writeShellApplication {
    name = "wordpress-recovery-export-core";
    runtimeInputs = exporterRuntimeInputs;
    text = ''
            set -o nounset
            umask 0077

            readonly state_root=${lib.escapeShellArg stateRoot}
            readonly backup_root=${lib.escapeShellArg backupRoot}
            readonly generations_root=${lib.escapeShellArg generationsRoot}
            readonly current_link=${lib.escapeShellArg currentLink}
            readonly uploads_root=${lib.escapeShellArg uploadsRoot}
            readonly database_name=${lib.escapeShellArg databaseName}

            fail() {
              printf 'wordpress recovery export: %s\n' "$*" >&2
              exit 1
            }

            ensure_root_directory() {
              local path="$1"

              if [[ -e "$path" || -L "$path" ]]; then
                [[ -d "$path" && ! -L "$path" ]] \
                  || fail "required directory is not a real directory: $path"
                [[ "$(stat --format=%u:%g:%a -- "$path")" == 0:0:700 ]] \
                  || fail "unsafe owner or mode on $path"
              else
                mkdir --mode=0700 -- "$path"
              fi
            }

            [[ "$(id --user)" == 0 ]] || fail "must run as root"
            [[ -S /run/mysqld/mysqld.sock ]] || fail "MariaDB socket is absent"
            [[ -d "$uploads_root" && ! -L "$uploads_root" ]] \
              || fail "uploads root is absent, a symlink, or not a directory"

            ensure_root_directory "$state_root"
            ensure_root_directory "$backup_root"
            ensure_root_directory "$generations_root"

            backup_device="$(stat --format=%d -- "$backup_root")"
            readonly backup_device
            [[ "$(stat --format=%d -- "$generations_root")" == "$backup_device" ]] \
              || fail "backup root and generations root are on different filesystems"

            readonly lock_path="$backup_root/export.lock"
            if [[ ! -e "$lock_path" && ! -L "$lock_path" ]]; then
              if ! ( set -o noclobber; : > "$lock_path" ) 2>/dev/null; then
                [[ -e "$lock_path" || -L "$lock_path" ]] \
                  || fail "unable to create the export lock"
              fi
            fi
            [[ -f "$lock_path" && ! -L "$lock_path" ]] \
              || fail "export lock is not a real regular file"
            [[ "$(stat --format=%u:%g:%a:%h -- "$lock_path")" == 0:0:600:1 ]] \
              || fail "unsafe owner, mode, or link count on the export lock"
            lock_path_identity="$(stat --format=%d:%i -- "$lock_path")"
            readonly lock_path_identity

            exec 9<>"$lock_path"
            [[ -f "$lock_path" && ! -L "$lock_path" ]] \
              || fail "export lock changed type while it was opened"
            [[ "$(stat --format=%u:%g:%a:%h -- "$lock_path")" == 0:0:600:1 ]] \
              || fail "export lock metadata changed while it was opened"
            [[ "$(stat --format=%d:%i -- "$lock_path")" == "$lock_path_identity" \
              && "$(stat --dereference --format=%d:%i -- /proc/self/fd/9)" == "$lock_path_identity" ]] \
              || fail "export lock identity changed while it was opened"
            flock --exclusive --nonblock 9 \
              || fail "another accepted or manual recovery export is running"

            previous_current_present=false
            previous_current_target=
            previous_current_identity=
            if [[ -e "$current_link" || -L "$current_link" ]]; then
              [[ -L "$current_link" ]] \
                || fail "current exists but is not a symlink"
              previous_current_identity="$(stat --format=%d:%i -- "$current_link")"
              previous_current_target="$(readlink -- "$current_link")"
              [[ -L "$current_link" \
                && "$(stat --format=%d:%i -- "$current_link")" == "$previous_current_identity" ]] \
                || fail "current changed while its initial identity was recorded"
              [[ "$previous_current_target" =~ ^generations/[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
                || fail "current has an unsafe target"
              [[ -d "$backup_root/$previous_current_target" \
                && ! -L "$backup_root/$previous_current_target" ]] \
                || fail "current does not name a real retained generation"
              previous_current_present=true
            fi

            started_at="$(date --utc --iso-8601=seconds)"
            timestamp="$(date --utc +%Y%m%dT%H%M%S.%NZ)"
            work_dir="$(mktemp --directory --tmpdir="$generations_root" \
              ".incomplete.$timestamp.XXXXXXXXXX")"
            export_id="$(basename -- "$work_dir" | sed 's/^\.incomplete\.//')"
            [[ "$export_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
              || fail "generated export identity is unsafe"
            final_dir="$generations_root/$export_id"
            [[ ! -e "$final_dir" && ! -L "$final_dir" ]] \
              || fail "generated export identity already exists"
            [[ "$(stat --format=%d -- "$work_dir")" == "$backup_device" ]] \
              || fail "working generation is on a different filesystem"

            temporary_link=
            published_current=false
            published_current_identity=
            publication_committed=false

            rollback_published_current() {
              local expected_target="generations/$export_id"
              local current_identity
              local rollback_identity
              local rollback_link

              [[ "$published_current" == true ]] || return 0

              if [[ ! -L "$current_link" ]]; then
                printf 'refusing to roll back current because it is no longer a symlink\n' >&2
                return 1
              fi
              if ! current_identity="$(stat --format=%d:%i -- "$current_link")"; then
                printf 'unable to identify published current link for rollback\n' >&2
                return 1
              fi
              if [[ "$(readlink -- "$current_link")" != "$expected_target" \
                || "$current_identity" != "$published_current_identity" ]]
              then
                printf 'refusing to roll back an unexpected current link\n' >&2
                return 1
              fi

              if [[ "$previous_current_present" == true ]]; then
                if [[ ! -d "$backup_root/$previous_current_target" \
                  || -L "$backup_root/$previous_current_target" ]]
                then
                  printf 'refusing to restore an absent or unsafe previous generation\n' >&2
                  return 1
                fi

                rollback_link="$backup_root/.current.rollback.$export_id"
                if [[ -e "$rollback_link" || -L "$rollback_link" ]]; then
                  printf 'refusing to use a colliding current rollback link\n' >&2
                  return 1
                fi
                if ! ln --symbolic -- "$previous_current_target" "$rollback_link"; then
                  printf 'unable to create current rollback link\n' >&2
                  return 1
                fi
                if ! rollback_identity="$(stat --format=%d:%i -- "$rollback_link")"; then
                  rm --force -- "$rollback_link"
                  printf 'unable to identify current rollback link\n' >&2
                  return 1
                fi

                if [[ ! -L "$current_link" \
                  || "$(readlink -- "$current_link")" != "$expected_target" \
                  || "$(stat --format=%d:%i -- "$current_link")" != "$published_current_identity" ]]
                then
                  rm --force -- "$rollback_link"
                  printf 'refusing to replace a current link that changed during rollback\n' >&2
                  return 1
                fi
                if ! mv -T --no-copy -- "$rollback_link" "$current_link"; then
                  rm --force -- "$rollback_link"
                  printf 'unable to restore previous current link\n' >&2
                  return 1
                fi
                if ! sync --file-system "$backup_root"; then
                  printf 'previous current link was restored but its parent sync failed\n' >&2
                  return 1
                fi
                if [[ ! -L "$current_link" \
                  || "$(readlink -- "$current_link")" != "$previous_current_target" \
                  || "$(stat --format=%d:%i -- "$current_link")" != "$rollback_identity" ]]
                then
                  printf 'previous current link failed post-rollback verification\n' >&2
                  return 1
                fi
              else
                if [[ ! -L "$current_link" \
                  || "$(readlink -- "$current_link")" != "$expected_target" \
                  || "$(stat --format=%d:%i -- "$current_link")" != "$published_current_identity" ]]
                then
                  printf 'refusing to remove a current link that changed during rollback\n' >&2
                  return 1
                fi
                if ! rm -- "$current_link"; then
                  printf 'unable to restore the previous absence of current\n' >&2
                  return 1
                fi
                if ! sync --file-system "$backup_root"; then
                  printf 'current was removed but its parent sync failed\n' >&2
                  return 1
                fi
                if [[ -e "$current_link" || -L "$current_link" ]]; then
                  printf 'current unexpectedly reappeared after rollback\n' >&2
                  return 1
                fi
              fi

              published_current=false
              printf 'restored the previous current state after publication failure\n' >&2
            }

            cleanup() {
              local status="$?"

              if [[ "$status" != 0 \
                && "$published_current" == true \
                && "$publication_committed" == false ]]
              then
                if ! rollback_published_current; then
                  printf '%s\n' \
                    'automatic current rollback failed; current is non-authoritative; only a separately verified dated accepted marker may be used for restore' >&2
                fi
              fi

              if [[ -n "$temporary_link" && -L "$temporary_link" ]]; then
                rm --force -- "$temporary_link"
              fi

              if [[ -n "$work_dir" && -d "$work_dir" && ! -L "$work_dir" ]]; then
                case "$work_dir" in
                  "$generations_root"/.incomplete.*)
                    rm --recursive --force --one-file-system -- "$work_dir"
                    ;;
                  *)
                    printf 'refusing to clean unexpected work path %q\n' "$work_dir" >&2
                    ;;
                esac
              fi

              exit "$status"
            }
            trap cleanup EXIT

            write_uploads_manifest() {
              local label="$1"
              local unsafe_entries="$work_dir/$label.unsafe.list0"
              local all_entries="$work_dir/$label.all.list0"
              local files="$work_dir/$label.files.list0"
              local hashes="$work_dir/$label.files.sha256z"
              local directories="$work_dir/$label.directories.list0"
              local statistics="$work_dir/$label.statistics"
              local uploads_device
              local entry
              local entry_device
              local file_size
              local file_count
              local directory_count
              local total_bytes=0

              (
                cd "$uploads_root"
                LC_ALL=C find -P . -xdev ! \( -type d -o -type f \) -print0 \
                  > "$unsafe_entries"
                LC_ALL=C find -P . -xdev -print0 \
                  | LC_ALL=C sort --zero-terminated > "$all_entries"
                LC_ALL=C find -P . -xdev -type f -print0 \
                  | LC_ALL=C sort --zero-terminated > "$files"
                LC_ALL=C find -P . -xdev -type d -print0 \
                  | LC_ALL=C sort --zero-terminated > "$directories"
              )

              if [[ -s "$unsafe_entries" ]]; then
                IFS= read -r -d "" entry < "$unsafe_entries" || true
                printf 'unsafe uploads entry type at %q\n' "$entry" >&2
                return 1
              fi

              uploads_device="$(stat --format=%d -- "$uploads_root")"
              while IFS= read -r -d "" entry; do
                entry_device="$(stat --format=%d -- "$uploads_root/$entry")"
                if [[ "$entry_device" != "$uploads_device" ]]; then
                  printf 'uploads mount boundary at %q\n' "$entry" >&2
                  return 1
                fi
              done < "$all_entries"

              (
                cd "$uploads_root"
                xargs -0 -r sha256sum --zero -- < "$files" > "$hashes"
              )

              file_count="$(tr --delete --complement '\000' < "$files" | wc --bytes)"
              directory_count="$(tr --delete --complement '\000' < "$directories" | wc --bytes)"

              while IFS= read -r -d "" entry; do
                file_size="$(stat --format=%s -- "$uploads_root/$entry")"
                total_bytes=$((total_bytes + file_size))
              done < "$files"

              printf 'file_count=%s\ndirectory_count=%s\ntotal_bytes=%s\n' \
                "$file_count" "$directory_count" "$total_bytes" > "$statistics"

              rm -- "$unsafe_entries" "$all_entries"
            }

            mariadb_query() {
              command mariadb \
                --protocol=socket \
                --socket=/run/mysqld/mysqld.sock \
                --user=root \
                --batch \
                --skip-column-names \
                --raw \
                --database="$database_name" \
                "$@"
            }

            write_database_inventory() {
              local label="$1"
              local table_engines="$work_dir/$label.table-engines.tsv"
              local count_statements="$work_dir/$label.table-count-statements.sql"
              local row_counts="$work_dir/$label.table-row-counts.tsv"
              local content_counts="$work_dir/$label.content-counts.tsv"
              local api_key_rows

              mariadb_query > "$table_engines" <<'SQL'
      SELECT HEX(TABLE_NAME), COALESCE(UPPER(ENGINE), '<NULL>')
      FROM information_schema.tables
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_TYPE = 'BASE TABLE'
      ORDER BY BINARY TABLE_NAME;
      SQL

              [[ -s "$table_engines" ]] || fail "database contains no base tables"
              if ! awk -F '\t' '
                NF != 2 || $1 !~ /^[0-9A-F]+$/ || $2 != "INNODB" { invalid = 1 }
                END { exit invalid }
              ' "$table_engines"
              then
                fail "database table set contains a malformed or non-InnoDB base table"
              fi

              api_key_rows="$(
                mariadb_query \
                  --execute="SELECT COUNT(*) FROM wp_options WHERE option_name = 'wordpress_api_key';"
              )"
              [[ "$api_key_rows" == 0 ]] \
                || fail "wordpress_api_key must be deleted before every dump"

              {
                printf '%s\n' \
                  'SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;' \
                  'START TRANSACTION WITH CONSISTENT SNAPSHOT;'
                mariadb_query <<'SQL'
      SELECT CONCAT(
        'SELECT ', QUOTE(HEX(TABLE_NAME)), ', COUNT(*) FROM `',
        REPLACE(TABLE_NAME, '`', '``'), '`;'
      )
      FROM information_schema.tables
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_TYPE = 'BASE TABLE'
      ORDER BY BINARY TABLE_NAME;
      SQL
                printf '%s\n' 'COMMIT;'
              } > "$count_statements"

              mariadb_query < "$count_statements" > "$row_counts"
              [[ -s "$row_counts" ]] || fail "database row-count inventory is empty"

              mariadb_query > "$content_counts" <<'SQL'
      SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
      START TRANSACTION WITH CONSISTENT SNAPSHOT;
      SELECT 'posts', COUNT(*) FROM wp_posts;
      SELECT 'published_posts', COUNT(*) FROM wp_posts WHERE post_type = 'post' AND post_status = 'publish';
      SELECT 'published_pages', COUNT(*) FROM wp_posts WHERE post_type = 'page' AND post_status = 'publish';
      SELECT 'attachments', COUNT(*) FROM wp_posts WHERE post_type = 'attachment';
      SELECT 'users', COUNT(*) FROM wp_users;
      SELECT 'comments', COUNT(*) FROM wp_comments;
      COMMIT;
      SQL
              [[ -s "$content_counts" ]] || fail "database content-count inventory is empty"
            }

            write_uploads_manifest before
            write_database_inventory before

            mariadb-dump \
              --protocol=socket \
              --socket=/run/mysqld/mysqld.sock \
              --user=root \
              --single-transaction \
              --quick \
              --skip-lock-tables \
              --hex-blob \
              --routines \
              --events \
              --triggers \
              --databases "$database_name" \
              > "$work_dir/database.sql"

            [[ -s "$work_dir/database.sql" ]] || fail "database dump is empty"
            if LC_ALL=C grep --quiet --fixed-strings \
              -- 'wordpress_api_key' "$work_dir/database.sql"
            then
              fail "database dump contains the forbidden wordpress_api_key option"
            fi

            write_database_inventory after

            for inventory_file in \
              table-engines.tsv \
              table-count-statements.sql \
              table-row-counts.tsv \
              content-counts.tsv
            do
              cmp --silent \
                "$work_dir/before.$inventory_file" \
                "$work_dir/after.$inventory_file" \
                || fail "database $inventory_file drifted across the dump"
              mv -T --no-copy -- \
                "$work_dir/after.$inventory_file" \
                "$work_dir/$inventory_file"
              rm -- "$work_dir/before.$inventory_file"
            done

            write_uploads_manifest after

            cmp --silent \
              "$work_dir/before.files.list0" \
              "$work_dir/after.files.list0" \
              || fail "uploads file set drifted during export"
            cmp --silent \
              "$work_dir/before.files.sha256z" \
              "$work_dir/after.files.sha256z" \
              || fail "uploads file content drifted during export"
            cmp --silent \
              "$work_dir/before.directories.list0" \
              "$work_dir/after.directories.list0" \
              || fail "uploads directory set drifted during export"
            cmp --silent \
              "$work_dir/before.statistics" \
              "$work_dir/after.statistics" \
              || fail "uploads count or size drifted during export"

            mv -T --no-copy -- \
              "$work_dir/after.files.sha256z" \
              "$work_dir/uploads.files.sha256z"
            mv -T --no-copy -- \
              "$work_dir/after.directories.list0" \
              "$work_dir/uploads.directories.list0"
            mv -T --no-copy -- \
              "$work_dir/after.statistics" \
              "$work_dir/uploads.statistics"
            rm -- \
              "$work_dir/before.files.list0" \
              "$work_dir/before.files.sha256z" \
              "$work_dir/before.directories.list0" \
              "$work_dir/before.statistics" \
              "$work_dir/after.files.list0"

            (
              cd "$work_dir"
              sha256sum -- \
                database.sql \
                table-engines.tsv \
                table-count-statements.sql \
                table-row-counts.tsv \
                content-counts.tsv \
                uploads.files.sha256z \
                uploads.directories.list0 \
                uploads.statistics \
                > artifacts.sha256
            )
            [[ "$(wc --lines < "$work_dir/artifacts.sha256")" == 8 ]] \
              || fail "artifact manifest has an unexpected schema"
            artifacts_manifest_sha256="$(
              sha256sum -- "$work_dir/artifacts.sha256" | awk '{print $1}'
            )"
            artifacts_manifest_bytes="$(stat --format=%s -- "$work_dir/artifacts.sha256")"

            completed_at="$(date --utc --iso-8601=seconds)"
            system_generation="$(readlink --canonicalize-existing /run/current-system)"
            printf '%s\n' \
              'format=2' \
              "export_id=$export_id" \
              "started_at=$started_at" \
              "completed_at=$completed_at" \
              "system_generation=$system_generation" \
              "database=$database_name" \
              'artifacts_manifest=artifacts.sha256' \
              "artifacts_manifest_sha256=$artifacts_manifest_sha256" \
              "artifacts_manifest_bytes=$artifacts_manifest_bytes" \
              > "$work_dir/export.marker"

            find -P "$work_dir" -xdev -type f -exec chmod 0400 -- {} +
            find -P "$work_dir" -xdev -depth -type d -exec chmod 0500 -- {} +

            mv -T --no-copy -- "$work_dir" "$final_dir"
            work_dir=

            sync --file-system "$final_dir"
            sync --file-system "$backup_root"

            if [[ "$previous_current_present" == true ]]; then
              [[ -L "$current_link" ]] \
                || fail "current changed while the export was running"
              [[ "$(readlink -- "$current_link")" == "$previous_current_target" ]] \
                || fail "current target changed while the export was running"
              [[ "$(stat --format=%d:%i -- "$current_link")" == "$previous_current_identity" ]] \
                || fail "current identity changed while the export was running"
            else
              [[ ! -e "$current_link" && ! -L "$current_link" ]] \
                || fail "current appeared while the export was running"
            fi

            temporary_link="$backup_root/.current.$export_id"
            [[ ! -e "$temporary_link" && ! -L "$temporary_link" ]] \
              || fail "temporary current link name collided"
            ln --symbolic -- "generations/$export_id" "$temporary_link"
            [[ "$(readlink -- "$temporary_link")" == "generations/$export_id" ]] \
              || fail "temporary current link verification failed"
            published_current_identity="$(stat --format=%d:%i -- "$temporary_link")"

            mv -T --no-copy -- "$temporary_link" "$current_link"
            published_current=true
            temporary_link=
            sync --file-system "$backup_root"

            [[ -L "$current_link" \
              && "$(readlink -- "$current_link")" == "generations/$export_id" ]] \
              || fail "published current link verification failed"

            printf '%s\n' "$export_id"
            publication_committed=true
            trap - EXIT
    '';
  };

  acceptedExport = pkgs.writeShellApplication {
    name = "wordpress-recovery-export-accepted";
    runtimeInputs = exporterRuntimeInputs;
    text = ''
      set -o nounset
      umask 0077

      readonly backup_root=${lib.escapeShellArg backupRoot}
      readonly accepted_root=${lib.escapeShellArg acceptedRoot}

      fail() {
        printf 'accepted WordPress recovery export: %s\n' "$*" >&2
        exit 1
      }

      export_marker_value() {
        local key="$1"
        local count

        count="$(grep --count -- "^$key=" "$generation/export.marker" || true)"
        [[ "$count" == 1 ]] \
          || fail "export marker key $key is absent or duplicated"
        sed --silent "s/^$key=//p" "$generation/export.marker"
      }

      [[ "$(id --user)" == 0 ]] || fail "must run as root"

      started_epoch="$(date +%s)"
      accepted_date="$(
        TZ=Europe/Prague date --date="@$started_epoch" +%F
      )"
      started_at="$(
        TZ=Europe/Prague date --date="@$started_epoch" --iso-8601=seconds
      )"
      window_open_epoch="$(TZ=Europe/Prague date --date="$accepted_date 00:30:00" +%s)"
      cutoff_epoch="$(TZ=Europe/Prague date --date="$accepted_date 00:50:00" +%s)"

      [[ "$started_epoch" -ge "$window_open_epoch" \
        && "$started_epoch" -lt "$cutoff_epoch" ]] \
        || fail "timer start is outside the accepted 00:30-00:50 Europe/Prague window"

      marker="$accepted_root/$accepted_date.marker"
      [[ ! -e "$marker" && ! -L "$marker" ]] \
        || fail "an accepted marker already exists for $accepted_date"

      started_system_generation="$(
        readlink --canonicalize-existing /run/current-system
      )" || fail "the active system generation is unavailable"

      export_id="$(${recoveryExport}/bin/wordpress-recovery-export-core)"
      [[ "$export_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
        || fail "exporter returned an unsafe identity"

      expected_target="generations/$export_id"
      generation="$backup_root/$expected_target"
      [[ -d "$generation" && ! -L "$generation" ]] \
        || fail "accepted generation is not a real directory"
      [[ -f "$generation/export.marker" \
        && ! -L "$generation/export.marker" ]] \
        || fail "accepted export marker is absent or unsafe"
      [[ "$(wc --lines < "$generation/export.marker")" == 9 ]] \
        || fail "accepted export marker has an unexpected schema"
      [[ "$(export_marker_value format)" == 2 ]] \
        || fail "accepted export has an unsupported marker format"
      [[ "$(export_marker_value export_id)" == "$export_id" ]] \
        || fail "accepted export marker has a different identity"

      if [[ -e "$accepted_root" || -L "$accepted_root" ]]; then
        [[ -d "$accepted_root" && ! -L "$accepted_root" ]] \
          || fail "accepted marker root is not a real directory"
        [[ "$(stat --format=%u:%g:%a -- "$accepted_root")" == 0:0:700 ]] \
          || fail "accepted marker root has unsafe metadata"
      else
        mkdir --mode=0700 -- "$accepted_root"
      fi

      marker_digest="$(sha256sum -- "$generation/export.marker" | awk '{print $1}')"
      completed_system_generation="$(
        readlink --canonicalize-existing /run/current-system
      )" || fail "the active system generation is unavailable"
      [[ "$completed_system_generation" == "$started_system_generation" ]] \
        || fail "system generation changed during the accepted export"
      [[ "$(export_marker_value system_generation)" == "$started_system_generation" ]] \
        || fail "the core export did not use the starting system generation"
      completed_epoch="$(date +%s)"
      completed_at="$(
        TZ=Europe/Prague date --date="@$completed_epoch" --iso-8601=seconds
      )"
      [[ "$completed_epoch" -lt "$cutoff_epoch" ]] \
        || fail "accepted export validation did not finish before 00:50 Europe/Prague"
      marker_published=false
      temporary_marker="$(mktemp --tmpdir="$accepted_root" \
        ".marker.$accepted_date.XXXXXXXXXX")"
      temporary_marker_identity=
      cleanup() {
        local status="$?"

        if [[ "$marker_published" == true ]]; then
          if [[ -f "$marker" && ! -L "$marker" \
            && "$(stat --format=%d:%i -- "$marker")" == "$temporary_marker_identity" ]]
          then
            rm --force -- "$marker" || true
            sync --file-system "$accepted_root" || true
            sync --file-system "$backup_root" || true
          else
            printf 'refusing to remove an unexpected accepted marker at %q\n' \
              "$marker" >&2
          fi
        fi

        if [[ -n "$temporary_marker" ]]; then
          rm --force -- "$temporary_marker" || true
        fi
        exit "$status"
      }
      trap cleanup EXIT

      printf '%s\n' \
        'format=2' \
        "accepted_date=$accepted_date" \
        "timer_started_at=$started_at" \
        "timer_completed_at=$completed_at" \
        "system_generation=$started_system_generation" \
        "export_id=$export_id" \
        "generation_target=$expected_target" \
        "export_marker_sha256=$marker_digest" \
        > "$temporary_marker"
      chmod 0400 "$temporary_marker"
      sync --file-system "$temporary_marker"
      temporary_marker_identity="$(stat --format=%d:%i -- "$temporary_marker")"

      marker_published=true
      if ! ln -- "$temporary_marker" "$marker"; then
        marker_published=false
        fail "accepted marker publication collided"
      fi
      rm -- "$temporary_marker"
      temporary_marker=
      sync --file-system "$accepted_root"
      sync --file-system "$backup_root"

      [[ -f "$marker" && ! -L "$marker" ]] \
        || fail "accepted marker publication failed"

      published_epoch="$(date +%s)"
      if [[ "$published_epoch" -ge "$cutoff_epoch" ]]; then
        rm -- "$marker"
        marker_published=false
        sync --file-system "$accepted_root"
        sync --file-system "$backup_root"
        fail "accepted marker publication did not finish before 00:50 Europe/Prague"
      fi

      trap - EXIT
    '';
  };

  manualExport = pkgs.writeShellApplication {
    name = "wordpress-recovery-export-manual";
    runtimeInputs = exporterRuntimeInputs;
    text = ''
      # This launcher has no accepted-marker path or marker-writing code. It
      # can refresh current, but cannot advance accepted backup health.
      exec ${recoveryExport}/bin/wordpress-recovery-export-core
    '';
  };

  recoveryHealthCheck = pkgs.writeShellApplication {
    name = "wordpress-recovery-export-health-check";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      set -o nounset

      readonly state_root=${lib.escapeShellArg stateRoot}
      readonly backup_root=${lib.escapeShellArg backupRoot}
      readonly generations_root=${lib.escapeShellArg generationsRoot}
      readonly accepted_root=${lib.escapeShellArg acceptedRoot}
      readonly first_expected_date=${lib.escapeShellArg configuredFirstExpectedDate}

      fail() {
        printf 'WordPress recovery health: %s\n' "$*" >&2
        exit 1
      }

      marker_value() {
        local key="$1"
        local count

        count="$(grep --count -- "^$key=" "$marker" || true)"
        [[ "$count" == 1 ]] || fail "marker key $key is absent or duplicated"
        sed --silent "s/^$key=//p" "$marker"
      }

      export_marker_value() {
        local key="$1"
        local count

        count="$(grep --count -- "^$key=" "$export_marker" || true)"
        [[ "$count" == 1 ]] \
          || fail "export marker key $key is absent or duplicated"
        sed --silent "s/^$key=//p" "$export_marker"
      }

      require_root_directory() {
        local path="$1"

        [[ -d "$path" && ! -L "$path" ]] \
          || fail "required recovery directory is absent or unsafe: $path"
        [[ "$(stat --format=%u:%g:%a -- "$path")" == 0:0:700 ]] \
          || fail "required recovery directory has unsafe metadata: $path"
      }

      [[ "$first_expected_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
        || fail "the first expected recovery-export date is not configured"
      normalized_first_expected_date="$(
        TZ=Europe/Prague date \
          --date="$first_expected_date 12:00:00" +%F
      )" || fail "the first expected recovery-export date is invalid"
      [[ "$normalized_first_expected_date" == "$first_expected_date" ]] \
        || fail "the first expected recovery-export date is invalid"

      now_epoch="$(date +%s)"
      today="$(TZ=Europe/Prague date --date="@$now_epoch" +%F)"
      today_cutoff_epoch="$(
        TZ=Europe/Prague date --date="$today 00:50:00" +%s
      )"
      if [[ "$now_epoch" -lt "$today_cutoff_epoch" ]]; then
        expected_date="$(
          TZ=Europe/Prague date --date="$today 12:00:00 yesterday" +%F
        )"
      else
        expected_date="$today"
      fi

      # The first expected date is pinned in reviewed configuration. It
      # grants at most one explicit initial grace period and cannot slide on
      # reboot or service restart. At 00:50 on that date, its marker becomes
      # mandatory.
      if [[ "$expected_date" < "$first_expected_date" ]]; then
        exit 0
      fi

      require_root_directory "$state_root"
      require_root_directory "$backup_root"
      require_root_directory "$generations_root"
      require_root_directory "$accepted_root"

      marker="$accepted_root/$expected_date.marker"
      [[ -f "$marker" && ! -L "$marker" ]] \
        || fail "the expected accepted marker is absent or unsafe"
      [[ "$(stat --format=%u:%g:%a:%h -- "$marker")" == 0:0:400:1 ]] \
        || fail "the expected accepted marker has unsafe metadata"
      [[ "$(wc --lines < "$marker")" == 8 ]] \
        || fail "the expected accepted marker has an unexpected schema"

      [[ "$(marker_value format)" == 2 ]] || fail "unsupported marker format"
      [[ "$(marker_value accepted_date)" == "$expected_date" ]] \
        || fail "accepted marker is for the wrong Europe/Prague date"

      started_at="$(marker_value timer_started_at)"
      completed_at="$(marker_value timer_completed_at)"
      started_epoch="$(TZ=Europe/Prague date --date="$started_at" +%s)"
      completed_epoch="$(TZ=Europe/Prague date --date="$completed_at" +%s)"
      window_open_epoch="$(
        TZ=Europe/Prague date --date="$expected_date 00:30:00" +%s
      )"
      cutoff_epoch="$(
        TZ=Europe/Prague date --date="$expected_date 00:50:00" +%s
      )"
      [[ "$started_epoch" -ge "$window_open_epoch" \
        && "$started_epoch" -lt "$cutoff_epoch" ]] \
        || fail "accepted timer start is outside its reviewed window"
      [[ "$completed_epoch" -ge "$started_epoch" \
        && "$completed_epoch" -lt "$cutoff_epoch" ]] \
        || fail "accepted completion is late or predates its start"

      marker_generation="$(marker_value system_generation)"

      export_id="$(marker_value export_id)"
      [[ "$export_id" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
        || fail "accepted export identity is unsafe"
      expected_target="generations/$export_id"
      [[ "$(marker_value generation_target)" == "$expected_target" ]] \
        || fail "accepted marker has an inconsistent generation target"

      generation="$backup_root/$expected_target"
      export_marker="$generation/export.marker"
      [[ -d "$generation" && ! -L "$generation" ]] \
        || fail "accepted generation is absent or unsafe"
      [[ "$(stat --format=%u:%g:%a -- "$generation")" == 0:0:500 ]] \
        || fail "accepted generation has unsafe metadata"
      [[ -f "$export_marker" && ! -L "$export_marker" ]] \
        || fail "accepted generation marker is absent or unsafe"
      [[ "$(stat --format=%u:%g:%a:%h -- "$export_marker")" == 0:0:400:1 ]] \
        || fail "accepted generation marker has unsafe metadata"
      [[ "$(wc --lines < "$export_marker")" == 9 ]] \
        || fail "accepted generation marker has an unexpected schema"
      [[ "$(export_marker_value format)" == 2 ]] \
        || fail "accepted generation has an unsupported marker format"
      [[ "$(export_marker_value export_id)" == "$export_id" ]] \
        || fail "accepted generation marker has a different identity"
      [[ "$(export_marker_value system_generation)" == "$marker_generation" ]] \
        || fail "accepted generation marker names a different system generation"
      [[ "$(export_marker_value database)" == ${lib.escapeShellArg databaseName} ]] \
        || fail "accepted generation marker names a different database"

      expected_digest="$(marker_value export_marker_sha256)"
      [[ "$expected_digest" =~ ^[0-9a-f]{64}$ ]] \
        || fail "accepted export marker digest is malformed"
      actual_digest="$(sha256sum -- "$export_marker" | awk '{print $1}')"
      [[ "$actual_digest" == "$expected_digest" ]] \
        || fail "accepted generation marker digest changed"

      artifacts_manifest_name="$(export_marker_value artifacts_manifest)"
      [[ "$artifacts_manifest_name" == artifacts.sha256 ]] \
        || fail "accepted generation names an unexpected artifact manifest"
      artifacts_manifest="$generation/$artifacts_manifest_name"
      [[ -f "$artifacts_manifest" && ! -L "$artifacts_manifest" ]] \
        || fail "accepted artifact manifest is absent or unsafe"
      [[ "$(stat --format=%u:%g:%a:%h -- "$artifacts_manifest")" == 0:0:400:1 ]] \
        || fail "accepted artifact manifest has unsafe metadata"

      expected_artifacts_digest="$(export_marker_value artifacts_manifest_sha256)"
      [[ "$expected_artifacts_digest" =~ ^[0-9a-f]{64}$ ]] \
        || fail "accepted artifact manifest digest is malformed"
      actual_artifacts_digest="$(sha256sum -- "$artifacts_manifest" | awk '{print $1}')"
      [[ "$actual_artifacts_digest" == "$expected_artifacts_digest" ]] \
        || fail "accepted artifact manifest digest changed"

      expected_artifacts_bytes="$(export_marker_value artifacts_manifest_bytes)"
      [[ "$expected_artifacts_bytes" =~ ^[1-9][0-9]*$ ]] \
        || fail "accepted artifact manifest size is malformed"
      [[ "$(stat --format=%s -- "$artifacts_manifest")" == "$expected_artifacts_bytes" ]] \
        || fail "accepted artifact manifest size changed"

      for artifact in \
        database.sql \
        table-engines.tsv \
        table-count-statements.sql \
        table-row-counts.tsv \
        content-counts.tsv \
        uploads.files.sha256z \
        uploads.directories.list0 \
        uploads.statistics
      do
        artifact_path="$generation/$artifact"
        [[ -f "$artifact_path" && ! -L "$artifact_path" ]] \
          || fail "accepted artifact $artifact is absent or unsafe"
        [[ "$(stat --format=%u:%g:%a:%h -- "$artifact_path")" == 0:0:400:1 ]] \
          || fail "accepted artifact $artifact has unsafe metadata"
      done

      temporary_manifest="$(mktemp)"
      cleanup() {
        local status="$?"
        rm --force -- "$temporary_manifest"
        exit "$status"
      }
      trap cleanup EXIT
      (
        cd "$generation"
        sha256sum -- \
          database.sql \
          table-engines.tsv \
          table-count-statements.sql \
          table-row-counts.tsv \
          content-counts.tsv \
          uploads.files.sha256z \
          uploads.directories.list0 \
          uploads.statistics
      ) > "$temporary_manifest"
      cmp --silent -- "$artifacts_manifest" "$temporary_manifest" \
        || fail "accepted artifact content changed"
      rm -- "$temporary_manifest"
      temporary_manifest=
      trap - EXIT
    '';
  };

  exporterServiceConfig = {
    Type = "oneshot";
    User = "root";
    Group = "root";
    SupplementaryGroups = [
      config.services.nginx.group
      config.services.mysql.group
    ];
    UMask = "0077";
    StateDirectory = stateDirectory;
    StateDirectoryMode = "0700";
    TimeoutStartSec = "15min";
    PrivateNetwork = true;
    RestrictAddressFamilies = [ "AF_UNIX" ];
    PrivateTmp = true;
    NoNewPrivileges = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectControlGroups = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    LockPersonality = true;
    RestrictSUIDSGID = true;
    CapabilityBoundingSet = "";
    ReadWritePaths = [ stateRoot ];
    ReadOnlyPaths = [ uploadsRoot ];
  };
in
{
  options.vpsfree.blog.recovery = {
    enableAcceptedTimer = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the accepted 00:30 Europe/Prague recovery-export timer. Keep
        false until the live managed-snapshot schedule has been rechecked and
        monitoring consumes wordpress-recovery-export-health-check.
      '';
    };

    firstExpectedDate = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[0-9]{4}-[0-9]{2}-[0-9]{2}");
      default = null;
      example = "2026-07-22";
      description = ''
        First Europe/Prague calendar date whose accepted export becomes
        mandatory at 00:50. Pin this date in the reviewed timer-enablement
        commit so the one-time initial grace cannot slide across reboots or
        service restarts.
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion = !cfg.enableAcceptedTimer || cfg.firstExpectedDate != null;
        message = ''
          vpsfree.blog.recovery.firstExpectedDate must be pinned when the
          accepted WordPress recovery-export timer is enabled
        '';
      }
    ];

    environment.systemPackages = [
      recoveryHealthCheck
    ];

    systemd.services.wordpress-recovery-export = {
      description = "Create the accepted portable WordPress recovery export";
      requires = [ "mysql.service" ];
      after = [ "mysql.service" ];
      unitConfig.RefuseManualStart = true;
      serviceConfig = exporterServiceConfig // {
        ExecStart = "${acceptedExport}/bin/wordpress-recovery-export-accepted";
      };
    };

    systemd.timers.wordpress-recovery-export = {
      wantedBy = lib.optionals cfg.enableAcceptedTimer [ "timers.target" ];
      timerConfig = {
        Unit = "wordpress-recovery-export.service";
        OnCalendar = "*-*-* 00:30:00 Europe/Prague";
        Persistent = false;
        RandomizedDelaySec = "0";
        AccuracySec = "1s";
      };
    };

    systemd.services.wordpress-recovery-export-manual = {
      description = "Manually refresh WordPress recovery data without accepting backup health";
      requires = [ "mysql.service" ];
      after = [ "mysql.service" ];
      serviceConfig = exporterServiceConfig // {
        ExecStart = "${manualExport}/bin/wordpress-recovery-export-manual";
      };
    };

    systemd.services.wordpress-recovery-export-health-check = {
      description = "Validate the expected accepted WordPress recovery export";
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        Group = "root";
        UMask = "0077";
        ExecStart = "${recoveryHealthCheck}/bin/wordpress-recovery-export-health-check";
        PrivateNetwork = true;
        RestrictAddressFamilies = [ "AF_UNIX" ];
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        LockPersonality = true;
        RestrictSUIDSGID = true;
        CapabilityBoundingSet = "";
        # The optional prefix preserves first-enable grace before the accepted
        # exporter has created its StateDirectory. ProtectSystem already
        # keeps the path read-only whenever it exists.
        ReadOnlyPaths = [ "-${stateRoot}" ];
      };
    };
  };
}
