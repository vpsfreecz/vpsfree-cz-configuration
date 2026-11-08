#!/usr/bin/env python3
"""Tiny mocked acquisition and transaction fixtures. Never contacts GitHub/machines."""
import hashlib
import gzip
import importlib.util
import io
import json
import multiprocessing
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import threading
import time
import stat
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location('blog_release', Path(__file__).resolve().parents[1] / 'tools/blog-static-release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def fixture(sha='a' * 40, css=b'body{}', extra=None):
    payload = {}
    for language in ('cs', 'en'):
        payload.update({language + '/index.html': b'<p>Fixture</p>', language + '/feed/index.xml': b'<rss/>',
                        language + '/css/site.' + 'c' * 64 + '.css': css,
                        language + '/wp-content/uploads/photo.png': b'Original image'})
    payload.update(extra or {})
    metadata = {'schema': 1, 'inputs': {'revision': sha, 'sourceNarHash': 'sha256-fixture', 'nixpkgsRevision': '1' * 40},
                'files': {name: release.digest(value) for name, value in payload.items()}}
    payload['metadata.json'] = release.encode(metadata)
    identity = {'schema': 1, 'repository': release.REPOSITORY, 'source_sha': sha,
                'workflow_path': release.WORKFLOW_PATH, 'run_id': 7, 'run_attempt': 1,
                'artifact_name': 'blog-' + sha, 'inputs': metadata['inputs'],
                'metadata_sha256': release.digest(payload['metadata.json'])}
    payload['release.json'] = release.encode(identity)
    archive = make_tar(payload)
    return archive, {**identity, 'archive_sha256': release.digest(archive)}, identity


def make_tar(files, special=None):
    target = io.BytesIO()
    with tarfile.open(fileobj=target, mode='w') as tar:
        for name, data in files.items():
            member = tarfile.TarInfo(name)
            member.size = len(data)
            tar.addfile(member, io.BytesIO(data))
        if special:
            member = tarfile.TarInfo(special[0])
            member.type = special[1]
            member.linkname = '../outside'
            tar.addfile(member)
    return gzip.compress(target.getvalue(), mtime=0)


def publication_fixture(base, module=release):
    base = Path(base)
    state = base / 'state'
    state.mkdir(exist_ok=True)
    control = base / 'control'
    control.mkdir(mode=0o750)
    (control / 'transaction.lock').touch(mode=0o660)
    policy = base / 'policy.json'
    policy.write_bytes(module.encode({'schema': 2, 'authority': 'hmac-upload-v1', 'repository': module.REPOSITORY,
        'workflow_path': module.WORKFLOW_PATH, 'enabled': True, 'state_dir': str(module.STATE), 'keep_releases': 5}))
    policy.chmod(0o444)
    active = base / 'active-policy'
    active.symlink_to(policy)
    generation = base / 'generation-1'
    generation.mkdir()
    system = base / 'current-system'
    system.symlink_to(generation)
    return module.Publication(policy, active, system, control, os.getuid(), state), state


class Artifact(unittest.TestCase):
    def test_malformed_paths_types_hashes_identity(self):
        archive, receipt, trusted = fixture()
        files = release.validate(archive, receipt, trusted)
        for name, kind in [('../escape', tarfile.REGTYPE), ('/absolute', tarfile.REGTYPE), ('cs/link', tarfile.SYMTYPE), ('cs/link', tarfile.LNKTYPE), ('cs/device', tarfile.CHRTYPE), ('cs/index.html', tarfile.REGTYPE)]:
            bad = make_tar(files, (name, kind))
            with self.assertRaises(release.Rejected):
                release.validate(bad, {**receipt, 'archive_sha256': release.digest(bad)}, trusted)
        with self.assertRaisesRegex(release.Rejected, 'digest'):
            release.validate(archive + b'corrupt', receipt, trusted)
        files['cs/index.html'] = b'Changed body'
        bad = make_tar(files)
        with self.assertRaisesRegex(release.Rejected, 'hash'):
            release.validate(bad, {**receipt, 'archive_sha256': release.digest(bad)}, trusted)
        with self.assertRaisesRegex(release.Rejected, 'identity'):
            release.validate(archive, {**receipt, 'source_sha': 'b' * 40}, trusted)
        dirty, dirty_receipt, dirty_trusted = fixture(sha='dirty')
        with self.assertRaisesRegex(release.Rejected, 'Dirty'):
            release.validate(dirty, dirty_receipt, dirty_trusted)


class Transaction(unittest.TestCase):
    def prepare(self, root, sha='a' * 40, css=b'body{}'):
        archive, receipt, trusted = fixture(sha, css)
        files = release.validate(archive, receipt, trusted)
        return release.stage(root, archive, receipt, files, {'artifact_id': 5, 'source_sha': sha})

    def test_atomic_switch_stale_rejection_retention_and_rollback(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            first = self.prepare(root)
            self.assertFalse((root / 'current').exists())
            authority = iter([True, False])
            with self.assertRaisesRegex(release.Rejected, 'policy refused at switch'):
                release._switch(root, first, lambda: next(authority), None)
            self.assertFalse((root / 'current').exists())
            with self.assertRaisesRegex(release.Rejected, 'policy refused'):
                release._switch(root, first, lambda: False, None)
            release._switch(root, first, lambda: True, None)
            previous = release.current_state(root)[2]
            second = self.prepare(root, 'b' * 40)
            release._switch(root, second, lambda: True, previous)
            with self.assertRaisesRegex(release.Rejected, 'Previous receipt'):
                release._switch(root, first, lambda: True, previous)
            now = release.current_state(root)[2]
            result = release._switch(root, first, lambda: True, now, rollback=True)
            self.assertEqual(result['outcome'], 'rollback')
            for key in (first, second):
                self.assertTrue((root / 'releases' / key).is_dir())
                self.assertTrue((root / 'releases' / (key + '.tar.gz')).is_file())
            self.assertTrue(list((root / 'assets/css').glob('*.css')))

    def test_immutable_conflict_and_interruption_reconciliation(self):
        for phase in ('before-pointer', 'after-pointer'):
            with tempfile.TemporaryDirectory() as d:
                root = Path(d)
                key = self.prepare(root)
                def interrupt(current):
                    if current == phase:
                        raise RuntimeError('fixture interruption')
                with self.assertRaises(RuntimeError):
                    release._switch(root, key, lambda: True, None, interrupt=interrupt)
                with release.serialized(root):
                    release.reconcile(root)
                self.assertEqual(release.current_state(root)[0] is not None, phase == 'after-pointer')
                self.assertFalse((root / 'receipts/pending.json').exists())
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            key = self.prepare(root)
            release._switch(root, key, lambda: True, None)
            second = self.prepare(root, 'b' * 40, b'Changed CSS at same immutable path')
            with self.assertRaisesRegex(release.Rejected, 'CSS path reuse'):
                release._switch(root, second, lambda: True, release.current_state(root)[2])

    def test_concurrent_requests_have_one_winner(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            key = self.prepare(root)
            results = []
            def activate():
                try:
                    release._switch(root, key, lambda: True, None)
                    results.append('activated')
                except release.Rejected:
                    results.append('stale')
            threads = [threading.Thread(target=activate) for _ in range(2)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            self.assertEqual(sorted(results), ['activated', 'stale'])

    def test_obsolete_cli_removed(self):
        for command in ('prepare', 'pull', 'activate'):
            result = subprocess.run([sys.executable, str(Path(release.__file__)), command], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('invalid choice', result.stderr)


class Retention(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.pub, self.root = publication_fixture(self.temporary.name)
        release.atomic_json(self.pub.control / 'state.json', {'schema': 2, 'paused': False, **self.pub.identity()})
        self.processes = multiprocessing.get_context('fork')

    def upload(self, number, sha=None):
        archive, receipt, _ = fixture(sha or format(number, '040x'))
        body = io.BytesIO()
        with zipfile.ZipFile(body, 'w') as bundle:
            bundle.writestr('payload.tar.gz', archive)
            bundle.writestr('receipt.json', release.encode(receipt))
        data = body.getvalue()
        return self.pub.upload(io.BytesIO(data), number, release.digest(data))

    def populate(self, count=8):
        return [self.upload(i)['release'] for i in range(1, count + 1)]

    def preserved(self):
        paths = [self.pub.control, self.root / 'receipts', self.root / 'assets']
        return {str(p): p.read_bytes() for base in paths for p in base.rglob('*') if p.is_file()}

    def test_newest_five_and_current_previous_floor_pins_preserve_audit_and_staging(self):
        keys = self.populate(9)
        first = next(json.loads(p.read_text()) for p in (self.root / 'receipts').glob('*.json')
                     if p.name.count('-') == 4 and json.loads(p.read_text()).get('release') == keys[0])
        first.update(previous_release=keys[2], old_pointer='releases/' + keys[2])
        release.atomic_json(self.root / 'receipts/current.json', first)
        (self.root / 'current').unlink()
        (self.root / 'current').symlink_to('releases/' + keys[0])
        floor = release.upload_floor(self.root)
        floor.update(release=keys[1], source_sha=keys[1][:40])
        release.atomic_json(self.root / 'receipts/upload-order.json', floor)
        stage_only = Transaction().prepare(self.root, 'f' * 40)
        incoming = self.root / 'releases/.incoming-uncommitted'
        incoming.mkdir(); (incoming / 'payload').write_bytes(b'not committed')
        before = self.preserved()
        plan = self.pub.prune(dry_run=True)
        self.assertEqual(set(plan['kept']), set(keys[4:]) | set(keys[:3]))
        self.assertEqual(plan['candidates'], [keys[3]])
        self.assertFalse((self.root / 'releases/.trash').exists())
        result = self.pub.prune()
        self.assertEqual(result['deleted'], [keys[3]])
        self.assertFalse((self.root / 'releases' / keys[3]).exists())
        self.assertFalse((self.root / 'releases' / (keys[3] + '.tar.gz')).exists())
        self.assertTrue((self.root / 'releases' / stage_only).is_dir())
        self.assertEqual((incoming / 'payload').read_bytes(), b'not committed')
        self.assertEqual(self.preserved(), before)
        with self.assertRaises(release.Rejected):
            release._switch(self.root, keys[3], lambda: True, release.current_state(self.root)[2], rollback=True)
        rolled = release._switch(self.root, keys[2], lambda: True, release.current_state(self.root)[2], rollback=True)
        self.assertEqual(rolled['outcome'], 'rollback')
        self.assertEqual(release.upload_floor(self.root)['run_number'], 9)
        with self.assertRaisesRegex(release.Rejected, 'Superseded'):
            self.upload(1)

    def test_duplicate_selection_and_equal_timestamp_ranking_is_deterministic(self):
        keys = self.populate(7)
        records = list((self.root / 'receipts').glob('*.json'))
        for path in records:
            data = json.loads(path.read_text())
            if data.get('outcome'):
                data['at'] = '2025-01-01T00:00:00+00:00'
                path.write_bytes(release.encode(data))
        duplicate = dict(json.loads((self.root / 'receipts/current.json').read_text()))
        duplicate.update(release=keys[0], source_sha=keys[0][:40],
                         archive_sha256=json.loads((self.root / 'receipts' / (keys[0] + '.json')).read_text())['archive_sha256'],
                         at='2025-01-02T00:00:00+00:00')
        release.atomic_json(self.root / 'receipts' / (str(release.uuid.uuid4()) + '.json'), duplicate)
        plan = self.pub.prune(dry_run=True)
        self.assertEqual(set(plan['kept']), {keys[0], *keys[3:]})
        self.assertEqual(set(plan['candidates']), set(keys[1:3]))

    def test_pause_pending_and_malformed_protected_references_make_no_retirement(self):
        self.populate()
        release.atomic_json(self.pub.control / 'state.json', {'schema': 2, 'paused': True})
        self.assertIn('paused', self.pub.prune()['skipped'])
        self.assertTrue(self.pub.prune(dry_run=True)['candidates'])
        self.assertFalse((self.root / 'releases/.trash').exists())
        release.atomic_json(self.pub.control / 'state.json', {'schema': 2, 'paused': False, **self.pub.identity()})
        pending = self.root / 'receipts/pending.json'; pending.write_bytes(b'{}')
        self.assertEqual(self.pub.prune()['skipped'], 'pending transaction')
        pending.unlink()
        current = release.current_state(self.root)[1]
        current['old_pointer'] = 'releases/' + 'e' * 40 + '-' + 'f' * 16
        release.atomic_json(self.root / 'receipts/current.json', current)
        with self.assertRaisesRegex(release.Rejected, 'Conflicting'):
            self.pub.prune()
        self.assertFalse((self.root / 'releases/.trash').exists())

    def test_interrupted_tree_archive_retirement_is_retried_without_receipt_rewrites(self):
        keys = self.populate()
        before = self.preserved()
        rename = release.os.rename
        def interrupted(source, destination, **options):
            if source.endswith('.tar.gz'):
                raise OSError('fixture archive retirement failure')
            return rename(source, destination, **options)
        with patch.object(release.os, 'rename', interrupted):
            self.assertIn('retirement_failure', self.pub.prune())
        self.assertFalse((self.root / 'releases' / keys[0]).exists())
        self.assertTrue((self.root / 'releases' / (keys[0] + '.tar.gz')).is_file())
        retried = self.pub.prune()
        self.assertIn(keys[0], retried['deleted'])
        self.assertFalse((self.root / 'releases' / (keys[0] + '.tar.gz')).exists())
        self.assertEqual(self.preserved(), before)

    def test_symlink_outside_sentinel_and_failed_deletion_remain_isolated(self):
        keys = self.populate()
        outside = Path(self.temporary.name) / 'outside'
        outside.write_bytes(b'outside sentinel')
        (self.root / 'releases' / keys[0] / 'escape').symlink_to(outside)
        failed = self.pub.prune()
        self.assertTrue(failed['cleanup_failures'])
        self.assertEqual(outside.read_bytes(), b'outside sentinel')
        link = next((self.root / 'releases/.trash').glob('*/' + keys[0] + '/escape'))
        link.unlink()
        self.assertIn(keys[0], self.pub.prune()['deleted'])
        self.assertEqual(outside.read_bytes(), b'outside sentinel')

    def test_prune_skips_real_busy_publication_and_staging_locks(self):
        self.populate()
        for lock_path in (self.pub.control / 'transaction.lock', self.root / 'transaction.lock'):
            ready, finish = self.processes.Event(), self.processes.Event()
            def hold():
                with lock_path.open('r+') as lock:
                    release.fcntl.flock(lock, release.fcntl.LOCK_EX)
                    ready.set(); finish.wait(10)
            process = self.processes.Process(target=hold); process.start()
            try:
                self.assertTrue(ready.wait(5))
                self.assertIn('lock busy', self.pub.prune()['skipped'])
            finally:
                finish.set(); process.join(5)
            self.assertEqual(process.exitcode, 0)

    def test_directory_symlink_and_missing_protected_payload_refuse_retirement(self):
        keys = self.populate()
        directory = self.root / 'releases'
        saved = self.root / 'saved-releases'
        directory.rename(saved)
        directory.symlink_to(saved)
        with self.assertRaises((OSError, release.Rejected)):
            self.pub.prune()
        directory.unlink(); saved.rename(directory)
        current_archive = directory / (keys[-1] + '.tar.gz')
        current_archive.rename(directory / 'orphan-preserved')
        with self.assertRaisesRegex(release.Rejected, 'Protected'):
            self.pub.prune()
        self.assertFalse((directory / '.trash').exists())

    def test_partial_bulk_deletion_and_overlapping_cleanup_are_idempotent(self):
        self.populate()
        unlink = release.os.unlink
        removed = []
        def interrupted(name, **options):
            if removed:
                raise OSError('fixture deletion interruption')
            removed.append(name)
            return unlink(name, **options)
        with patch.object(release.os, 'unlink', interrupted):
            self.assertTrue(self.pub.prune()['cleanup_failures'])
        self.assertTrue(removed)
        self.assertTrue(self.pub.prune()['deleted'])
        self.assertFalse(self.pub.prune()['cleanup_failures'])

    def test_upload_waits_for_prune_metadata_lock_then_commits_first_attempt(self):
        self.populate()
        held, finish, uploaded = self.processes.Event(), self.processes.Event(), self.processes.Queue()
        def metadata():
            plan = release.retention_plan
            def held_plan(*args):
                held.set(); finish.wait(10)
                return plan(*args)
            with patch.object(release, 'retention_plan', held_plan):
                self.pub.prune()
        def upload():
            try: uploaded.put(self.upload(9)['selected'])
            except BaseException as error: uploaded.put(type(error).__name__)
        pruner = self.processes.Process(target=metadata); pruner.start()
        self.assertTrue(held.wait(5))
        uploader = self.processes.Process(target=upload); uploader.start()
        try:
            time.sleep(0.1)
            self.assertTrue(uploader.is_alive())
        finally:
            finish.set(); pruner.join(5); uploader.join(5)
        self.assertEqual(pruner.exitcode, 0); self.assertEqual(uploader.exitcode, 0)
        self.assertIs(uploaded.get(timeout=2), True)
        self.assertEqual(release.upload_floor(self.root)['run_number'], 9)

    def test_slow_failed_bulk_deletion_holds_neither_lock_and_upload_succeeds(self):
        self.populate()
        deleting, finish, answer = self.processes.Event(), self.processes.Event(), self.processes.Queue()
        def prune():
            def slow(*args):
                deleting.set(); finish.wait(10)
                raise OSError('fixture deletion failure')
            with patch.object(release, 'remove_retired', slow):
                answer.put(self.pub.prune())
        process = self.processes.Process(target=prune); process.start()
        try:
            self.assertTrue(deleting.wait(5))
            uploaded = self.upload(9)
            self.assertTrue(uploaded['selected'])
        finally:
            finish.set(); process.join(5)
        self.assertEqual(process.exitcode, 0)
        self.assertTrue(answer.get(timeout=2)['cleanup_failures'])
        self.assertEqual(release.upload_floor(self.root)['run_number'], 9)
        self.assertTrue(self.pub.prune()['deleted'])

    def test_historical_restage_keeps_stage_lock_until_publication_commit(self):
        keys = self.populate()
        self.pub.prune()
        self.assertFalse((self.root / 'releases' / keys[0]).exists())
        staged, finish, answer = self.processes.Event(), self.processes.Event(), self.processes.Queue()
        def upload():
            stage = release.stage_locked
            def held(*args):
                key = stage(*args); staged.set(); finish.wait(10); return key
            with patch.object(release, 'stage_locked', held):
                try: answer.put(self.upload(9, format(1, '040x'))['selected'])
                except BaseException as error: answer.put(type(error).__name__)
        process = self.processes.Process(target=upload); process.start()
        try:
            self.assertTrue(staged.wait(5))
            self.assertIn('lock busy', self.pub.prune()['skipped'])
            with self.pub.lock(blocking=False):
                pass
        finally:
            finish.set(); process.join(5)
        self.assertEqual(process.exitcode, 0)
        self.assertIs(answer.get(timeout=2), True)
        self.assertEqual(release.current_state(self.root)[1]['release'], keys[0])


class Durability(unittest.TestCase):
    def test_stage_payload_archive_and_directories_precede_completed_receipt(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            archive, receipt, trusted = fixture(extra={'cs/nested/deep/example.html': b'body'})
            files = release.validate(archive, receipt, trusted)
            events = []
            fsync, replace = release.os.fsync, release.os.replace
            def synced(fd):
                events.append(('sync', os.readlink('/proc/self/fd/' + str(fd)), stat.S_ISREG(os.fstat(fd).st_mode), stat.S_IMODE(os.fstat(fd).st_mode)))
                return fsync(fd)
            def renamed(source, target):
                events.append(('replace', str(target), False))
                return replace(source, target)
            with patch.object(release.os, 'fsync', synced), patch.object(release.os, 'replace', renamed):
                key = release.stage(root, archive, receipt, files, {})
            exposed = next(i for i, event in enumerate(events) if event[:2] == ('replace', str(root / 'releases' / key)))
            eligible = next(i for i, event in enumerate(events) if event[:2] == ('replace', str(root / 'receipts' / (key + '.json'))))
            regular = [event[1] for event in events[:exposed] if event[0] == 'sync' and event[2]]
            self.assertTrue(all(any(p.endswith('/' + name) for p in regular) for name in files))
            self.assertTrue(any(p.endswith('.tar.gz') for p in regular))
            self.assertTrue(all(event[3] == 0o444 for event in events[:exposed] if event[0] == 'sync' and event[2]))
            self.assertTrue(any(event[0] == 'sync' and event[1].endswith('/cs/nested/deep') for event in events[:exposed]))
            self.assertTrue(any(event[:2] == ('sync', str(root / 'releases')) for event in events[exposed:eligible]))

    def test_flush_failures_never_make_new_stage_or_pointer_eligible(self):
        for failure in ('payload', 'archive', 'tree-directory', 'releases-directory'):
            with tempfile.TemporaryDirectory() as d:
                root = Path(d)
                archive, receipt, trusted = fixture()
                files = release.validate(archive, receipt, trusted)
                original = release.os.fsync
                def fail(fd):
                    path = os.readlink('/proc/self/fd/' + str(fd))
                    selected = ((failure == 'payload' and path.endswith('/cs/index.html'))
                        or (failure == 'archive' and path.endswith('.tar.gz'))
                        or (failure == 'tree-directory' and path.endswith('/tree/cs'))
                        or (failure == 'releases-directory' and path == str(root / 'releases')))
                    if selected:
                        raise OSError('fixture flush failure')
                    return original(fd)
                with self.subTest(failure=failure), patch.object(release.os, 'fsync', fail):
                    with self.assertRaises(OSError):
                        release.stage(root, archive, receipt, files, {})
                self.assertFalse(list((root / 'receipts').glob('*.json')))
                self.assertFalse((root / 'current').is_symlink())

    def test_older_stage_reuse_explicit_activation_and_css_have_flush_barriers(self):
        for phase in ('reuse', 'activate', 'css-file', 'css-directory', 'idempotent'):
            with tempfile.TemporaryDirectory() as d:
                root = Path(d)
                archive, receipt, trusted = fixture()
                files = release.validate(archive, receipt, trusted)
                key = release.stage(root, archive, receipt, files, {})
                if phase == 'idempotent':
                    release._switch(root, key, lambda: True, None)
                expected = release.current_state(root)[2]
                original = release.os.fsync
                def fail(fd):
                    path = os.readlink('/proc/self/fd/' + str(fd))
                    if ((phase in ('reuse', 'activate') and path.endswith('/' + key + '/cs/index.html'))
                            or (phase == 'css-file' and '/assets/css/' in path)
                            or (phase in ('css-directory', 'idempotent') and path.endswith('/assets/css'))):
                        raise OSError('fixture retained flush failure')
                    return original(fd)
                with self.subTest(phase=phase), patch.object(release.os, 'fsync', fail):
                    with self.assertRaises(OSError):
                        if phase == 'reuse':
                            release.stage(root, archive, receipt, files, {})
                        else:
                            release._switch(root, key, lambda: True, expected)
                self.assertEqual(release.current_state(root)[2], expected)
                self.assertFalse((root / 'receipts/pending.json').exists())


@unittest.skipUnless(os.getuid() == 0 and len(Path('/proc/self/uid_map').read_text().splitlines()) > 1,
                     'requires the explicitly isolated subordinate-UID namespace')
class RealPrivilegeBoundary(unittest.TestCase):
    """Actual kernel UID/group checks; never run against host content paths."""
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.base.chmod(0o755)
        self.publication, self.root = publication_fixture(self.base)
        self.first = Transaction().prepare(self.root)
        self.second = Transaction().prepare(self.root, 'b' * 40)
        release._switch(self.root, self.second, lambda: True, None)
        for path in [self.root, *self.root.rglob('*')]:
            os.chown(path, 1, 1, follow_symlinks=False)
        os.chown(self.publication.control, 0, 1)
        os.chown(self.publication.control / 'transaction.lock', 0, 1)
        self.account = patch.object(release.pwd, 'getpwnam', return_value=SimpleNamespace(pw_uid=1, pw_gid=1))
        self.groups = patch.object(release.os, 'getgrouplist', return_value=[1, 2])
        self.account.start(); self.groups.start()
        self.addCleanup(self.account.stop); self.addCleanup(self.groups.stop)
        self.outside = self.base / 'outside'
        self.outside.mkdir(mode=0o705)
        self.sentinel = self.outside / ('site.' + 'c' * 64 + '.css')
        self.sentinel.write_bytes(b'body{}')
        self.sentinel.chmod(0o644)
        self.snapshot = (self.sentinel.read_bytes(), stat.S_IMODE(self.sentinel.stat().st_mode), stat.S_IMODE(self.outside.stat().st_mode))

    def assert_sentinel(self):
        self.assertEqual((self.sentinel.read_bytes(), stat.S_IMODE(self.sentinel.stat().st_mode),
                          stat.S_IMODE(self.outside.stat().st_mode)), self.snapshot)

    def rollback(self):
        return self.publication.rollback(self.root, self.first, release.current_state(self.root)[2])

    def test_drop_is_irreversible_and_root_lock_is_inherited(self):
        def identity():
            regained = False
            try:
                os.setresuid(0, 0, 0)
                regained = True
            except PermissionError:
                pass
            caps = [x for x in Path('/proc/self/status').read_text().splitlines() if x.startswith('CapEff:')][0]
            return {'uids': os.getresuid(), 'gids': os.getresgid(), 'groups': os.getgroups(), 'regained': regained, 'caps': caps}
        value = release.content_as_release(identity)
        self.assertEqual(value['uids'], [1, 1, 1]); self.assertEqual(value['gids'], [1, 1, 1])
        self.assertEqual(value['groups'], [1, 2]); self.assertFalse(value['regained'])
        self.assertTrue(value['caps'].endswith('0000000000000000'))
        self.assertEqual(self.rollback()['outcome'], 'rollback')
        self.assertTrue(self.publication.control_state()['paused'])
        self.publication.exit(self.root)
        self.assertEqual(self.publication.status()['mode'], 'resumed')

    def test_prune_inspection_and_recursive_deletion_run_only_as_fixed_content_uid(self):
        self.publication.exit(self.root)
        def prepare():
            for number in range(1, 8):
                archive, receipt, trusted = fixture(format(number, '040x'))
                key = release.stage(self.root, archive, receipt, release.validate(archive, receipt, trusted), {})
                release._switch(self.root, key, lambda: True, release.current_state(self.root)[2])
            return True
        self.assertTrue(release.content_as_release(prepare))
        remove = release.remove_retired
        def unprivileged(*args):
            self.assertEqual(os.getresuid(), (1, 1, 1))
            self.assertEqual(os.getresgid(), (1, 1, 1))
            return remove(*args)
        with patch.object(release, 'remove_retired', unprivileged):
            result = self.publication.prune()
        self.assertTrue(result['deleted'])
        self.assertFalse(result['cleanup_failures'])
        self.assert_sentinel()

    def test_ancestor_and_dangling_final_css_symlinks_cannot_write_or_chmod_root_files(self):
        css = self.root / 'assets/css'
        saved = self.root / 'assets/saved'
        css.rename(saved)
        css.symlink_to(self.outside)
        with self.assertRaises(release.Rejected):
            self.rollback()
        self.assert_sentinel()
        css.unlink(); saved.rename(css)
        final = css / self.sentinel.name
        final.unlink()
        final.symlink_to(self.outside / 'new-root-file')
        with self.assertRaises(release.Rejected):
            self.rollback()
        self.assertFalse((self.outside / 'new-root-file').exists())
        self.assert_sentinel()

    def test_concurrent_css_ancestor_replacement_has_no_privileged_side_effect(self):
        css = self.root / 'assets/css'; good = self.root / 'assets/good'
        css.rename(good); css.symlink_to(good)
        ready_read, ready_write = os.pipe()
        attacker = os.fork()
        if attacker == 0:
            os.close(ready_read)
            os.setgroups([1, 2]); os.setresgid(1, 1, 1); os.setresuid(1, 1, 1)
            os.write(ready_write, b'1'); os.close(ready_write)
            try:
                while not (self.root / 'stop-attack').exists():
                    for target in (good, self.outside):
                        temporary = self.root / 'assets/attacker.new'
                        temporary.symlink_to(target)
                        os.replace(temporary, css)
            finally:
                os._exit(0)
        os.close(ready_write)
        self.assertEqual(os.read(ready_read, 1), b'1'); os.close(ready_read)
        try:
            for _ in range(12):
                current = release.current_state(self.root)[1]['release']
                key = self.first if current == self.second else self.second
                try:
                    self.publication.rollback(self.root, key, release.current_state(self.root)[2])
                except release.Rejected:
                    pass
                self.assert_sentinel()
        finally:
            (self.root / 'stop-attack').touch()
            _, status = os.waitpid(attacker, 0)
        self.assertTrue(os.WIFEXITED(status))
        self.assert_sentinel()

    def test_receipt_reconcile_and_status_do_not_gain_root_file_access(self):
        receipts = self.root / 'receipts'
        receipts.rename(self.root / 'safe-receipts')
        receipts.symlink_to(self.outside)
        for path in (self.root / 'safe-receipts').iterdir():
            if path.is_file():
                target = self.outside / path.name
                target.write_bytes(path.read_bytes()); target.chmod(0o644)
        pending = self.outside / 'pending.json'
        pending.write_bytes((self.outside / 'current.json').read_bytes()); pending.chmod(0o644)
        before = {p.name: (p.read_bytes(), stat.S_IMODE(p.stat().st_mode)) for p in self.outside.iterdir()}
        with self.assertRaises(release.Rejected):
            self.rollback()
        self.assertTrue(self.publication.control_state()['paused'])
        with self.assertRaises(release.Rejected):
            self.publication.exit(self.root)
        self.assertTrue(self.publication.control_state()['paused'])
        protected = self.outside / 'current.json'; protected.chmod(0o600)
        self.assertEqual(self.publication.status()['mode'], 'paused')
        protected.chmod(0o644)
        self.assertEqual(before, {p.name: (p.read_bytes(), stat.S_IMODE(p.stat().st_mode)) for p in self.outside.iterdir()})
        self.assert_sentinel()

    def test_root_content_cli_rejects_before_policy_or_token_access(self):
        for command in ('prepare', 'pull', 'activate'):
            result = subprocess.run([sys.executable, str(Path(release.__file__)), command], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('invalid choice', result.stderr)
        self.assert_sentinel()


if __name__ == '__main__':
    unittest.main(verbosity=1)
