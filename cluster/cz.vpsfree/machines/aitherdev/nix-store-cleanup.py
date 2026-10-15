#!/usr/bin/env python3
"""Clean this host's Nix GC roots and profile history; dry-run by default.

Examples:
  ~/bin/nix-store-cleanup
  ~/bin/nix-store-cleanup --days 14 --verbose
  sudo ~/bin/nix-store-cleanup --apply --gc

Policy:
  * Remove dangling GC-root registrations, never their missing targets.
  * Remove completed /tmp/**/os-test-* trees and their root registrations
    after --days inactive days. A completion result and run lock are required.
    Live process references and .keep markers protect runs. Unknown layouts
    remain untouched. Use --no-test-roots to retain all live test outputs.
  * For standard Nix profiles, remove generations older than --days, keeping
    --keep generations through the current one, all newer generations after a
    rollback, and generations matching the running/booted system.
  * Keep all other live roots, including confctl deployments, development
    sessions/clusters, dev-workspaces package history and Home Manager's current
    generation. A root's age alone cannot establish that it is unused.

Deleting registrations alone does not reclaim store space: --apply --gc also
runs GC through this host's Nix daemon socket, regardless of NIX_REMOTE.
Nix retains store paths still referenced by another root.
Removed generations cease to be rollback options. System boot menus will be
refreshed on the next normal system rebuild. Run without concurrent profile
updates or jobs using the selected old test outputs. Errors stop cleanup before
GC; rerunning is supported. Store paths are never manually deleted. Only recognized temporary test trees
are recursively removed. Cleanup and pressure GC share a host lock.

Nix reference: https://nix.dev/manual/nix/2.34/command-ref/nix-env/delete-generations.html
"""

import argparse
import fcntl
import shutil
from contextlib import ExitStack
from collections import Counter, defaultdict
import os
from pathlib import Path
import pwd
import re
import shlex
import stat
import subprocess
import sys
import time


LOCK_FILE = '/run/lock/nix-store-cleanup.lock'
PROC = Path('/proc')
GCROOTS = Path('/nix/var/nix/gcroots')
PROFILES = Path('/nix/var/nix/profiles')
STORE = Path('/nix/store')
GENERATION = re.compile(r'(.+)-(\d+)-link$')
GC_COMMAND = ['nix-store', '--store', 'unix:///nix/var/nix/daemon-socket/socket', '--gc']


def symlinks(directory):
    """Do not follow symlink directories, especially gcroots/profiles."""
    if not directory.exists():
        return
    def fail(error):
        raise error
    for parent, dirs, files in os.walk(directory, followlinks=False, onerror=fail):
        for name in sorted(dirs + files):
            path = Path(parent) / name
            if path.is_symlink():
                yield path


def snapshot(path):
    info = path.lstat()
    if not stat.S_ISLNK(info.st_mode):
        raise RuntimeError(f'Expected a symlink: {path}')
    return (info.st_dev, info.st_ino, info.st_mtime_ns, os.readlink(path))


def link_target(path):
    target = Path(os.readlink(path))
    return Path(os.path.abspath(path.parent / target))


def is_missing(path):
    # Permission errors must never be mistaken for a dangling root.
    # Linux protected_symlinks can reject root following a user's link in /tmp.
    # Resolve using lstat/readlink first, then stat the final target directly.
    try:
        path.resolve(strict=True).stat()
        return False
    except (FileNotFoundError, NotADirectoryError):
        return True


def managed(path):
    parts = path.parts
    return (any(part in {'.dev-clusters', 'dev-workspaces', '.confctl'}
                   for part in parts)
            or ('vpsfree.cz' in parts
                and any(part in {'work', 'worktrees', 'archive'} for part in parts)))


def protected(path):
    return (managed(path)
            or path == STORE or STORE in path.parents
            or path == PROFILES or PROFILES in path.parents
            or ('nix' in path.parts and 'profiles' in path.parts)
            or path.name in {'current-system', 'booted-system'})


def tree_snapshot(directory):
    """Bind a completed run to its contents, without following output links."""
    entries = []
    for parent, dirs, files in os.walk(directory, followlinks=False):
        for name in sorted(dirs + files):
            path = Path(parent) / name
            info = path.lstat()
            entries.append((str(path.relative_to(directory)), info.st_ino,
                            info.st_size, info.st_mtime_ns, info.st_ctime_ns))
    return sorted(entries)


def held(directory):
    for parent in [directory, *directory.parents]:
        if parent == Path('/tmp'):
            break
        if (parent / '.keep').exists() or (parent / '.keep').is_symlink():
            return True
    return False


def process_uses(directory, own_lock_fd):
    """Inspect cwd and open descriptors; do not read process environments."""
    prefix = str(directory) + '/'
    for process in PROC.iterdir():
        if not process.name.isdecimal():
            continue
        try:
            descriptors = [process / 'cwd', *list((process / 'fd').iterdir())]
        except (FileNotFoundError, ProcessLookupError):
            continue
        except PermissionError:
            # An unprivileged preview cannot prove another user's run is idle.
            return True
        for descriptor in descriptors:
            if process.name == str(os.getpid()) and descriptor == process / 'fd' / str(own_lock_fd):
                continue
            try:
                target = os.readlink(descriptor).removesuffix(' (deleted)')
            except (FileNotFoundError, ProcessLookupError, OSError) as error:
                if isinstance(error, PermissionError):
                    return True
                continue
            if target == str(directory) or target.startswith(prefix):
                return True
    return False


def test_lock(directory):
    path = directory / '.lock'
    if not path.is_file() or path.is_symlink():
        return None
    file = path.open('rb')
    try:
        fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        file.close()
        return None
    return file


def completed_test(directory, cutoff):
    result = directory / 'test-result.txt'
    if not result.is_file() or result.is_symlink() or held(directory):
        return None
    if result.stat().st_size > 4096 or result.read_text().strip() not in {
        'passed', 'failed', 'expected_success', 'expected_failure', 'unexpected_failure',
        'unexpected_success', 'skipped', 'error', 'success', 'failure'
    }:
        return None
    before = tree_snapshot(directory)
    if not before or max(max(entry[3], entry[4]) for entry in before) >= cutoff * 1e9:
        return None
    lock = test_lock(directory)
    if lock is None:
        return None
    try:
        if process_uses(directory, lock.fileno()):
            return None
        return before
    finally:
        lock.close()


def root_action(root, cutoff, prune_tests):
    if root.name in {'profiles', 'current-system', 'booted-system'}:
        return None
    root_snapshot = snapshot(root)
    target = link_target(root)
    if is_missing(root):
        return ('dangling', root, root_snapshot, None, None)
    if not prune_tests or protected(target):
        return None
    if (Path('/tmp') not in target.parents or target.name != 'config.json'
            or not target.parent.name.startswith('os-test-')
            or not target.is_symlink()):
        return None
    if STORE not in link_target(target).parents:
        return None
    if target.parent.resolve(strict=True) != target.parent:
        # A lexical /tmp name is not authority over an aliased external tree.
        return None
    if max(root.lstat().st_mtime, target.lstat().st_mtime) >= cutoff:
        return None
    contents = completed_test(target.parent, cutoff)
    if contents is None:
        return None
    return ('old-test', root, root_snapshot, target, (snapshot(target), contents))


def profile_directories():
    yield PROFILES
    for user in pwd.getpwall():
        if user.pw_uid == 0 or (user.pw_uid >= 1000 and user.pw_dir.startswith('/home/')):
            yield Path(user.pw_dir) / '.local/state/nix/profiles'
    state_home = os.environ.get('XDG_STATE_HOME')
    if state_home and os.path.isabs(state_home):
        yield Path(state_home) / 'nix/profiles'


def profile_plan(profile, generations, cutoff, keep, system_targets):
    current_link = link_target(profile)
    current_match = GENERATION.fullmatch(current_link.name)
    if (current_link.parent != profile.parent or current_match is None
            or current_match[1] != profile.name):
        raise RuntimeError(f'Unrecognized current generation for {profile}')
    current = int(current_match[2])
    if current not in generations:
        raise RuntimeError(f'Missing current generation for {profile}')
    retained = set(sorted(n for n in generations if n <= current)[-keep:])
    retained.update(n for n in generations if n >= current)
    remove = []
    for number, path in sorted(generations.items()):
        if (number not in retained and path.lstat().st_mtime < cutoff
                and path.resolve() not in system_targets):
            remove.append(number)
    return remove


def remove_root(action):
    kind, root, expected_root, target, expected_target = action
    if snapshot(root) != expected_root:
        raise RuntimeError(f'Root changed during cleanup: {root}')
    if kind == 'dangling':
        if not is_missing(root):
            raise RuntimeError(f'Dangling root became live: {root}')
        root.unlink()
        return
    lock = test_lock(target.parent)
    if lock is None:
        raise RuntimeError(f'Test became busy or lost its run lock: {target.parent}')
    try:
        link, contents = expected_target
        if (snapshot(target) != link or tree_snapshot(target.parent) != contents
                or held(target.parent) or process_uses(target.parent, lock.fileno())):
            raise RuntimeError(f'Test changed or became active: {target.parent}')
        shutil.rmtree(target.parent)
        root.unlink()
    finally:
        lock.close()


def positive(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError('must be a positive integer')
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument('--apply', action='store_true', help='perform cleanup (requires root)')
    mode.add_argument('--dry-run', action='store_true', help='preview only (the default)')
    parser.add_argument('--days', type=positive, default=7, help='minimum age in days (default: 7)')
    parser.add_argument('--keep', type=positive, default=2,
                        help='generations to retain through current (default: 2)')
    parser.add_argument('--no-test-roots', action='store_true', help='retain live temporary test roots')
    parser.add_argument('--gc', action='store_true', help='run Nix GC after cleanup with --apply')
    parser.add_argument('--verbose', action='store_true', help='list every selected root')
    args = parser.parse_args()
    with ExitStack() as guards:
        return clean(args, guards)


def clean(args, guards):
    if args.apply and os.geteuid() != 0:
        raise RuntimeError('--apply requires root; run this script with sudo')
    if args.apply:
        lock = guards.enter_context(open(LOCK_FILE, 'a'))
        fcntl.flock(lock, fcntl.LOCK_EX)
    cutoff = time.time() - args.days * 86400
    errors = []
    roots = list(symlinks(GCROOTS))
    actions = []
    for root in roots:
        try:
            action = root_action(root, cutoff, not args.no_test_roots)
            if action:
                actions.append(action)
        except OSError as error:
            errors.append(f'{root}: {error}')
    system_targets = {Path(p).resolve() for p in ['/run/current-system', '/run/booted-system']}
    for root in roots:
        if root.name in {'current-system', 'booted-system'}:
            system_targets.add(root.resolve())
    groups = defaultdict(dict)
    profile_links = set()
    for directory in dict.fromkeys(profile_directories()):
        try:
            profile_links.update(symlinks(directory))
        except PermissionError as error:
            errors.append(f'{directory}: {error}')
    # Also find profiles outside standard locations if their generations are
    # registered roots. Runtime-managed workspace profiles are kept separately.
    for root in roots:
        target = link_target(root)
        if GENERATION.fullmatch(target.name):
            profile_links.add(target)
    for link in sorted(profile_links):
        match = GENERATION.fullmatch(link.name)
        if match and not managed(link):
            groups[link.parent / match[1]][int(match[2])] = link
    plans = []
    for profile, generations in sorted(groups.items()):
        try:
            if not profile.is_symlink():
                print(f'KEEP orphan/unrecognized profile: {profile}')
                continue
            remove = profile_plan(profile, generations, cutoff, args.keep, system_targets)
            expected = snapshot(profile)
            expected_generations = {n: snapshot(generations[n]) for n in remove}
            plans.append((profile, remove, expected, expected_generations))
        except (OSError, RuntimeError) as error:
            errors.append(f'{profile}: {error}')
    counts = Counter(action[0] for action in actions)
    print(f'{"APPLY" if args.apply else "DRY RUN"}: roots older than {args.days} days; keep {args.keep} profile generations')
    print(f'GC-root links: {len(roots)}; dangling: {counts["dangling"]}; old test roots: {counts["old-test"]}; retained: {len(roots) - len(actions)}')
    for kind in ['dangling', 'old-test']:
        selected = [action for action in actions if action[0] == kind]
        for _, root, _, target, _ in (selected if args.verbose else selected[:5]):
            print(f'REMOVE {kind}: {root} -> {target or link_target(root)}')
        if not args.verbose and len(selected) > 5:
            print(f'  ... {len(selected) - 5} more; --verbose lists all')
    for profile, remove, _, _ in plans:
        print(f'PROFILE {profile}: remove {", ".join(map(str, remove)) or "none"}')
    print(f'Profile generations selected: {sum(len(plan[1]) for plan in plans)}')
    for error in errors:
        print(f'INCOMPLETE SCAN: {error}', file=sys.stderr)
    if not args.apply:
        if args.gc:
            print(f'Would run: {shlex.join(GC_COMMAND)} (space reclaimed is unknown until GC runs)')
        print('No changes made. Use sudo with --apply --gc to clean and reclaim space.')
        return 0
    if errors:
        raise RuntimeError('Scan incomplete; no cleanup performed')
    for profile, remove, expected, expected_generations in plans:
        if not remove:
            continue
        if snapshot(profile) != expected or any(
                snapshot(profile.parent / f'{profile.name}-{n}-link') != value
                for n, value in expected_generations.items()):
            raise RuntimeError(f'Profile changed during cleanup: {profile}')
        command = ['nix-env', '--profile', str(profile), '--delete-generations', *map(str, remove)]
        print(shlex.join(command), flush=True)
        subprocess.run(command, check=True)
    for action in actions:
        remove_root(action)
    print(f'Removed {len(actions)} GC-root registrations.')
    if args.gc:
        subprocess.run(GC_COMMAND, check=True)
    else:
        print(f'Store space has not been reclaimed. Run {shlex.join(GC_COMMAND)} when ready.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f'ERROR: {error}; GC was not started by this script after this failure.', file=sys.stderr)
        sys.exit(1)
