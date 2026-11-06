#!/usr/bin/env python3
"""Tiny mocked acquisition and transaction fixtures. Never contacts GitHub/machines."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import threading
import unittest
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
    with tarfile.open(fileobj=target, mode='w:gz') as tar:
        for name, data in files.items():
            member = tarfile.TarInfo(name)
            member.size = len(data)
            tar.addfile(member, io.BytesIO(data))
        if special:
            member = tarfile.TarInfo(special[0])
            member.type = special[1]
            member.linkname = '../outside'
            tar.addfile(member)
    return target.getvalue()


class API:
    def __init__(self):
        self.sha = 'a' * 40
        self.run = {'id': 7, 'workflow_id': 99, 'path': release.WORKFLOW_PATH, 'head_sha': self.sha,
                    'head_branch': 'main', 'event': 'push', 'status': 'completed', 'conclusion': 'success',
                    'repository': {'full_name': release.REPOSITORY}, 'head_repository': {'full_name': release.REPOSITORY}}
        archive, receipt, _ = fixture()
        zipped = io.BytesIO()
        with zipfile.ZipFile(zipped, 'w') as z:
            z.writestr('payload.tar.gz', archive)
            z.writestr('receipt.json', release.encode(receipt))
        self.zipped = zipped.getvalue()
        self.artifacts = [{'id': 5, 'name': 'blog-' + self.sha, 'expired': False}]
        self.protected = True

    def api(self, path):
        if '/branches/main' in path:
            return {'protected': self.protected, 'commit': {'sha': self.sha}}
        if '/workflows/' in path:
            return {'workflow_runs': [self.run]}
        return {'artifacts': self.artifacts}

    def artifact(self, ident):
        assert ident == 5
        return self.zipped


class Artifact(unittest.TestCase):
    def test_trusted_acquisition_and_missing_exact_head(self):
        api = API()
        archive, receipt, files, facts = release.acquire(api, 99)
        self.assertEqual(facts['source_sha'], api.sha)
        self.assertIn('cs/feed/index.xml', files)
        for field, value in [('head_sha', 'b' * 40), ('workflow_id', 98), ('path', 'untrusted.yml'), ('event', 'pull_request'), ('conclusion', 'failure')]:
            bad = API()
            bad.run[field] = value
            with self.assertRaises(release.Rejected):
                release.acquire(bad, 99)
        bad = API()
        bad.run['repository'] = {'full_name': 'untrusted/blog'}
        with self.assertRaises(release.Rejected):
            release.acquire(bad, 99)
        for artifacts in ([], [{'id': 5, 'name': 'blog-' + api.sha, 'expired': True}], [{'id': 5, 'name': 'blog-' + 'b' * 40, 'expired': False}]):
            bad = API()
            bad.artifacts = artifacts
            with self.assertRaisesRegex(release.Rejected, api.sha):
                release.acquire(bad, 99)
        bad = API()
        bad.protected = False
        with self.assertRaises(release.Rejected):
            release.acquire(bad, 99)

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
            heads = iter(['a' * 40, 'b' * 40])
            with self.assertRaisesRegex(release.Rejected, 'Stale authorized source head at switch'):
                release._switch_fixtureable(root, first, lambda: next(heads), lambda: True, None)
            self.assertFalse((root / 'current').exists())
            with self.assertRaisesRegex(release.Rejected, 'admission'):
                release._switch_fixtureable(root, first, lambda: 'a' * 40, lambda: False, None)
            release._switch_fixtureable(root, first, lambda: 'a' * 40, lambda: True, None)
            previous = release.current_state(root)[2]
            second = self.prepare(root, 'b' * 40)
            with self.assertRaisesRegex(release.Rejected, 'Stale authorized'):
                release._switch_fixtureable(root, second, lambda: 'c' * 40, lambda: True, previous)
            release._switch_fixtureable(root, second, lambda: 'b' * 40, lambda: True, previous)
            with self.assertRaisesRegex(release.Rejected, 'Previous receipt'):
                release._switch_fixtureable(root, first, lambda: 'a' * 40, lambda: True, previous)
            now = release.current_state(root)[2]
            result = release._switch_fixtureable(root, first, lambda: 'a' * 40, lambda: True, now, rollback=True)
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
                    release._switch_fixtureable(root, key, lambda: 'a' * 40, lambda: True, None, interrupt=interrupt)
                with release.serialized(root):
                    release.reconcile(root)
                self.assertEqual(release.current_state(root)[0] is not None, phase == 'after-pointer')
                self.assertFalse((root / 'receipts/pending.json').exists())
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            key = self.prepare(root)
            release._switch_fixtureable(root, key, lambda: 'a' * 40, lambda: True, None)
            second = self.prepare(root, 'b' * 40, b'Changed CSS at same immutable path')
            with self.assertRaisesRegex(release.Rejected, 'CSS path reuse'):
                release._switch_fixtureable(root, second, lambda: 'b' * 40, lambda: True, release.current_state(root)[2])

    def test_concurrent_requests_have_one_winner(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            key = self.prepare(root)
            results = []
            def activate():
                try:
                    release._switch_fixtureable(root, key, lambda: 'a' * 40, lambda: True, None)
                    results.append('activated')
                except release.Rejected:
                    results.append('stale')
            threads = [threading.Thread(target=activate) for _ in range(2)]
            for thread in threads:
                thread.start()
            for thread in threads:
                thread.join()
            self.assertEqual(sorted(results), ['activated', 'stale'])

    def test_production_cli_has_no_admission_override(self):
        result = subprocess.run(['python3', str(Path(release.__file__)), 'activate'], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('machine-admission-unavailable', result.stderr)


unittest.main(verbosity=1)
