#!/usr/bin/env python3
"""Offline upload authority, ordering, crash and protocol acceptance."""
import email.message
import importlib.util
import io
import json
import hashlib
import hmac
import os
import sys
sys.dont_write_bytecode = True
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch
import zipfile


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

base = Path(__file__).resolve().parents[1]
fixtures = load('fixtures', base / 'tests/blog-static-release.py')
release = fixtures.release
receiver = load('upload', base / 'tools/blog-upload.py')
KEY = b'synthetic-deployment-key-32-bytes-minimum'


def package(sha='a' * 40, run_id=7, attempt=1):
    archive, receipt, _ = fixtures.fixture(sha)
    # Repackage fixture metadata and envelope for the intended run attempt.
    files = release.validate(archive, receipt, receipt)
    identity = {k: v for k, v in receipt.items() if k != 'archive_sha256'}
    identity.update(run_id=run_id, run_attempt=attempt)
    files['release.json'] = release.encode(identity)
    archive = fixtures.make_tar(files)
    receipt = {**identity, 'archive_sha256': release.digest(archive)}
    stream = io.BytesIO()
    with zipfile.ZipFile(stream, 'w') as z:
        z.writestr(zipfile.ZipInfo('payload.tar.gz', (1980, 1, 1, 0, 0, 0)), archive)
        z.writestr(zipfile.ZipInfo('receipt.json', (1980, 1, 1, 0, 0, 0)), release.encode(receipt))
    return stream.getvalue()


class Protocol(unittest.TestCase):
    def headers(self, body=b'fixture', number='12'):
        digest = hashlib.sha256(body).hexdigest()
        values = {'Content-Length': str(len(body)), 'Content-Type': 'application/zip',
                  'X-Blog-Run-Number': number, 'X-Blog-Body-SHA256': digest,
                  'X-Blog-Signature': 'sha256=' + hmac.new(KEY, receiver.signing_message(number, digest), hashlib.sha256).hexdigest()}
        headers = email.message.Message()
        for k, v in values.items(): headers[k] = v
        return headers

    def test_signature_identity_and_header_bounds(self):
        headers = self.headers()
        self.assertEqual(receiver.authenticate('POST', receiver.PATH, headers, KEY)[:2], (7, 12))
        for name, value in [('Content-Length', '0'), ('Content-Length', str(receiver.MAX_BYTES + 1)),
                            ('Transfer-Encoding', 'chunked'), ('Content-Encoding', 'gzip'),
                            ('X-Blog-Run-Number', '01'), ('X-Blog-Body-SHA256', 'b' * 64),
                            ('X-Blog-Signature', 'sha256=' + '0' * 64), ('Content-Type', 'application/json')]:
            bad = self.headers()
            del bad[name]
            bad[name] = value
            with self.subTest(header=name), self.assertRaises(receiver.UploadError):
                receiver.authenticate('POST', receiver.PATH, bad, KEY)
        for name in list(headers):
            bad = self.headers(); bad[name] = bad[name]
            with self.assertRaises(receiver.UploadError): receiver.authenticate('POST', receiver.PATH, bad, KEY)
            bad = self.headers(); del bad[name]
            with self.assertRaises(receiver.UploadError): receiver.authenticate('POST', receiver.PATH, bad, KEY)
        for method, path in [('GET', receiver.PATH), ('POST', receiver.PATH + '?x=1'), ('POST', '/_hooks/github/build')]:
            with self.assertRaises(receiver.UploadError): receiver.authenticate(method, path, headers, KEY)
        with self.assertRaises(receiver.UploadError): receiver.authenticate('POST', receiver.PATH, headers, b'wrong')

    def handler(self, body, headers=None, publisher=None, busy=False, server=None, stream=None):
        from types import SimpleNamespace
        import threading
        handler = object.__new__(receiver.Handler)
        handler.path = receiver.PATH
        handler.headers = headers or self.headers(body)
        handler.rfile = stream if stream is not None else io.BytesIO(body)
        handler.connection = SimpleNamespace(settimeout=lambda timeout: None)
        lock = threading.Lock()
        if busy: lock.acquire()
        handler.server = server or SimpleNamespace(key=KEY, busy=lock, publication=publisher)
        responses = []
        handler.reply = lambda status, value: responses.append((status, value))
        handler.do_POST()
        return responses

    def publication_server(self):
        from types import SimpleNamespace
        import threading
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        pub, root = fixtures.publication_fixture(temporary.name, module=receiver.release)
        server = SimpleNamespace(key=KEY, busy=threading.Lock(), publication=pub)
        with patch.object(receiver.release.os, 'geteuid', return_value=0), patch.object(receiver.release, 'content_as_release', side_effect=lambda action: action()):
            pub.exit(root)
        return pub, server

    def switch_and_resume(self, pub, resume=True):
        generation = pub.system.parent / 'generation-2'
        with patch.object(receiver.release.os, 'geteuid', return_value=0), patch.object(receiver.release, 'content_as_release', side_effect=lambda action: action()):
            pub.enter()
            generation.mkdir()
            pub.system.unlink()
            pub.system.symlink_to(generation)
            if resume:
                selected = receiver.release.Publication(pub.compiled, pub.active, pub.system, pub.control, pub.owner, pub.root)
                selected.exit(pub.root)
        return generation

    def test_authentication_and_busy_refusals_do_not_publish_or_read(self):
        publisher = Mock()
        publisher.allowed.side_effect = AssertionError('Refused request checked publication')
        publisher.upload.side_effect = AssertionError('Refused request published content')
        stream = Mock()
        stream.read.side_effect = AssertionError('Refused request read a body')
        bad = self.headers(b'body')
        bad.replace_header('X-Blog-Signature', 'sha256=' + '0' * 64)
        self.assertEqual(self.handler(b'body', bad, publisher=publisher, stream=stream)[0][0], 401)
        self.assertEqual(self.handler(b'body', busy=True, publisher=publisher, stream=stream)[0][0], 503)
        publisher.allowed.assert_not_called()
        publisher.upload.assert_not_called()
        stream.read.assert_not_called()

    def test_new_upload_on_same_server_after_same_policy_system_change(self):
        pub, server = self.publication_server()
        first = package()
        self.assertEqual(self.handler(first, self.headers(first, '1'), server=server)[0][0], 200)
        policy = pub.compiled.read_bytes()
        old_control = pub.control_state()
        generation = self.switch_and_resume(pub, resume=False)
        second = package('b' * 40, 8)
        self.assertEqual(self.handler(second, self.headers(second, '2'), server=server)[0][0], 503)
        receiver.release.atomic_json(pub.control / 'state.json', old_control)
        self.assertEqual(self.handler(second, self.headers(second, '2'), server=server)[0][0], 503)
        selected = receiver.release.Publication(pub.compiled, pub.active, pub.system, pub.control, pub.owner, pub.root)
        with patch.object(receiver.release.os, 'geteuid', return_value=0), patch.object(receiver.release, 'content_as_release', side_effect=lambda action: action()):
            selected.exit(pub.root)
        self.assertEqual(self.handler(second, self.headers(second, '2'), server=server)[0][0], 200)
        self.assertIs(server.publication, pub)
        self.assertEqual(pub.compiled.read_bytes(), policy)
        self.assertEqual(receiver.release.current_state(pub.root)[1]['publication']['system'], str(generation))
        self.assertEqual(receiver.release.upload_floor(pub.root)['run_number'], 2)

    def test_upload_crossing_body_or_staging_succeeds_after_explicit_resume(self):
        for phase in ('body', 'staging'):
            with self.subTest(phase=phase):
                pub, server = self.publication_server()
                first = package()
                self.assertEqual(self.handler(first, self.headers(first, '1'), server=server)[0][0], 200)
                second = package('b' * 40, 8)
                if phase == 'body':
                    stream = io.BytesIO(second)
                    read = stream.read
                    def crossing_read(size):
                        self.switch_and_resume(pub)
                        return read(size)
                    with patch.object(stream, 'read', side_effect=crossing_read):
                        response = self.handler(second, self.headers(second, '2'), server=server, stream=stream)
                else:
                    stage = receiver.release.stage_locked
                    def crossing_stage(*args):
                        key = stage(*args)
                        self.switch_and_resume(pub)
                        return key
                    with patch.object(receiver.release, 'stage_locked', side_effect=crossing_stage):
                        response = self.handler(second, self.headers(second, '2'), server=server)
                self.assertEqual(response[0][0], 200)
                self.assertIs(server.publication, pub)
                current = receiver.release.current_state(pub.root)[1]
                self.assertEqual(current['source_sha'], 'b' * 40)
                self.assertEqual((pub.root / 'current').readlink(), Path('releases') / current['release'])
                self.assertEqual(current['publication']['system'], str(pub.system.resolve()))
                self.assertEqual(receiver.release.upload_floor(pub.root)['run_number'], 2)
                self.assertFalse((pub.root / 'receipts/pending.json').exists())
                paths = [pub.root / 'receipts' / name for name in ('current.json', 'upload-order.json')]
                committed = [path.read_bytes() for path in paths]
                self.assertEqual(self.handler(second, self.headers(second, '2'), server=server)[0][0], 200)
                self.assertEqual(self.handler(first, self.headers(first, '1'), server=server)[0][0], 409)
                conflict = package('b' * 40, 9)
                self.assertEqual(self.handler(conflict, self.headers(conflict, '2'), server=server)[0][0], 409)
                self.assertEqual([path.read_bytes() for path in paths], committed)

    def test_fresh_upload_still_refuses_paused_mismatched_control_and_changed_policy(self):
        pub, server = self.publication_server()
        body = package()
        stream = Mock()
        stream.read.side_effect = AssertionError('Disallowed publication read a body')
        for control in ({'schema': 2, 'paused': True}, {'schema': 2, 'paused': False, **pub.identity(), 'system': '/wrong-generation'}):
            receiver.release.atomic_json(pub.control / 'state.json', control)
            self.assertEqual(self.handler(body, server=server, stream=stream)[0][0], 503)
        replacement = pub.compiled.with_name('replacement-policy.json')
        data = json.loads(pub.compiled.read_text()); data['keep_releases'] += 1
        replacement.write_bytes(receiver.release.encode(data)); replacement.chmod(0o444)
        pub.active.unlink(); pub.active.symlink_to(replacement)
        selected = receiver.release.Publication(replacement, pub.active, pub.system, pub.control, pub.owner, pub.root)
        with patch.object(receiver.release.os, 'geteuid', return_value=0), patch.object(receiver.release, 'content_as_release', side_effect=lambda action: action()):
            selected.exit(pub.root)
        self.assertEqual(self.handler(body, server=server, stream=stream)[0][0], 409)
        stream.read.assert_not_called()

    def test_actual_body_tamper_short_busy_and_durable_response(self):
        from types import SimpleNamespace
        observed = []
        def publish(body, number, digest):
            observed.append(body.read())
            return {'selected': True, 'receipt_sha256': 'a' * 64}
        pub = SimpleNamespace(allowed=lambda: True, upload=publish)
        self.assertEqual(self.handler(b'actual bytes', publisher=pub)[0][0], 200)
        self.assertEqual(observed, [b'actual bytes'])
        observed.clear()
        self.assertEqual(self.handler(b'tampered', self.headers(b'original'), pub)[0][0], 400)
        self.assertEqual(self.handler(b'short', self.headers(b'longer body'), pub)[0][0], 400)
        self.assertEqual(self.handler(b'body', publisher=pub, busy=True)[0][0], 503)
        self.assertFalse(observed)
        def failed(*args): raise OSError('fsync failure')
        self.assertEqual(self.handler(b'body', publisher=SimpleNamespace(allowed=lambda: True, upload=failed))[0][0], 500)
        def paused(): raise release.Paused('paused')
        # receiver and fixture each load their own module instance.
        def receiver_paused(): raise receiver.release.Paused('paused')
        self.assertEqual(self.handler(b'body', publisher=SimpleNamespace(allowed=receiver_paused))[0][0], 503)

    def test_zip_paths_members_size_and_identity(self):
        release.upload_package(io.BytesIO(package()))
        for names in [('payload.tar.gz',), ('../payload.tar.gz', 'receipt.json'),
                      ('payload.tar.gz', 'receipt.json', 'extra'), ('receipt.json', 'receipt.json')]:
            stream = io.BytesIO()
            with zipfile.ZipFile(stream, 'w') as z:
                for name in names: z.writestr(name, b'{}')
            with self.assertRaises(release.Rejected): release.upload_package(io.BytesIO(stream.getvalue()))
        with patch.object(release, 'MAX_BYTES', 10), self.assertRaises(release.Rejected):
            release.upload_package(io.BytesIO(package()))
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, 'w') as z:
            item = zipfile.ZipInfo('payload.tar.gz'); item.external_attr = 0o120777 << 16
            z.writestr(item, b'link'); z.writestr('receipt.json', b'{}')
        with self.assertRaises(release.Rejected): release.upload_package(io.BytesIO(stream.getvalue()))


class Publication(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.pub, self.root = fixtures.publication_fixture(self.temporary.name)
        with patch.object(release.os, 'geteuid', return_value=0), patch.object(release, 'content_as_release', side_effect=lambda action: action()):
            self.pub.exit(self.root)

    def upload(self, body=None, number=1, **kwargs):
        body = body or package()
        return self.pub.upload(io.BytesIO(body), number, release.digest(body), **kwargs)

    def test_current_identical_retry_conflicts_supersession_and_attempts(self):
        first = self.upload()
        self.assertEqual(first, self.upload())
        self.assertEqual(first['receipt_sha256'], release.current_state(self.root)[2])
        with self.assertRaisesRegex(release.Rejected, 'Conflicting'):
            self.pub.upload(io.BytesIO(package()), 1, 'f' * 64)
        for body in (package(run_id=8), package(sha='b' * 40)):
            with self.assertRaisesRegex(release.Rejected, 'identity conflict'): self.upload(body)
        second = self.upload(package(attempt=2))
        self.assertNotEqual(first['receipt_sha256'], second['receipt_sha256'])
        with self.assertRaisesRegex(release.Rejected, 'Superseded'): self.upload()
        self.upload(package('b' * 40, run_id=8), number=2)
        with self.assertRaisesRegex(release.Rejected, 'Superseded'): self.upload(package(attempt=2))
        self.assertEqual(release.upload_floor(self.root)['run_number'], 2)

    def test_rollback_retains_floor_and_identical_old_request_cannot_undo_it(self):
        first = self.upload()
        second_body = package('b' * 40, 8)
        second = self.upload(second_body, 2)
        with patch.object(release.os, 'geteuid', return_value=0), patch.object(release, 'content_as_release', side_effect=lambda action: action()):
            self.pub.rollback(self.root, first['release'], second['receipt_sha256'])
            self.assertTrue(self.pub.control_state()['paused'])
            self.pub.exit(self.root)
        self.assertEqual(release.upload_floor(self.root)['run_number'], 2)
        with self.assertRaisesRegex(release.Rejected, 'no longer selected'): self.upload(second_body, 2)
        with self.assertRaisesRegex(release.Rejected, 'Superseded'): self.upload()
        self.upload(package('c' * 40, 9), 3)

    def test_crash_reconciliation_before_and_after_pointer_and_floor_write(self):
        for phase in ('before-pointer', 'after-pointer', 'floor-write'):
            with self.subTest(phase=phase), tempfile.TemporaryDirectory() as temporary:
                self.pub, self.root = fixtures.publication_fixture(temporary)
                with patch.object(release.os, 'geteuid', return_value=0), patch.object(release, 'content_as_release', side_effect=lambda action: action()): self.pub.exit(self.root)
                def interrupt(at):
                    if at == phase: raise RuntimeError('interruption')
                if phase == 'floor-write':
                    with patch.object(release, 'persist_floor', side_effect=OSError('flush failure')), self.assertRaises(OSError): self.upload()
                else:
                    with self.assertRaises(RuntimeError): self.upload(interrupt=interrupt)
                self.assertTrue((self.root / 'receipts/pending.json').exists())
                with self.pub.lock(): release.reconcile(self.root)
                floor = release.upload_floor(self.root)
                self.assertEqual(floor is not None, phase != 'before-pointer')
                result = self.upload()
                self.assertTrue(result['selected'])
                self.assertEqual(release.upload_floor(self.root)['run_number'], 1)

    def test_higher_number_same_content_durable_and_pause_during_stage(self):
        first = self.upload()
        second = self.upload(number=2)
        self.assertEqual(first['release'], second['release'])
        self.assertNotEqual(first['receipt_sha256'], second['receipt_sha256'])
        self.assertEqual(release.upload_floor(self.root)['run_number'], 2)
        stage = release.stage_locked
        def pausing(*args):
            key = stage(*args)
            with patch.object(release.os, 'geteuid', return_value=0): self.pub.enter()
            return key
        with patch.object(release, 'stage_locked', pausing), self.assertRaises(release.Paused):
            self.upload(package('b' * 40, 8), 3)
        self.assertEqual(release.current_state(self.root)[2], second['receipt_sha256'])
        self.assertEqual(release.upload_floor(self.root)['run_number'], 2)
        self.assertTrue(self.pub.control_state()['paused'])

    def test_root_controls_and_retained_old_receipt_compatibility(self):
        with self.assertRaisesRegex(release.Rejected, 'require root'): self.pub.enter()
        with self.assertRaisesRegex(release.Rejected, 'require root'): self.pub.exit(self.root)
        self.pub.control.chmod(0o770)
        with self.assertRaisesRegex(release.Rejected, 'control directory'): self.upload()
        self.pub.control.chmod(0o750)
        archive, receipt, trusted = fixtures.fixture()
        key = release.stage(self.root, archive, receipt, release.validate(archive, receipt, trusted), {})
        path = self.root / 'receipts' / (key + '.json')
        old = json.loads(path.read_text()); old['api_facts'] = old.pop('authority')
        path.write_bytes(release.encode(old))
        self.assertEqual(release.retained_release(self.root, key)[0]['schema'], 1)
        release.atomic_json(self.pub.control / 'state.json', {'schema': 1, 'paused': False})
        with self.assertRaisesRegex(release.Rejected, 'Incompatible control'): self.upload()

    def test_pause_policy_generation_and_old_schema_fail_closed(self):
        with patch.object(release.os, 'geteuid', return_value=0): self.pub.enter()
        with self.assertRaises(release.Paused): self.upload()
        with patch.object(release.os, 'geteuid', return_value=0), patch.object(release, 'content_as_release', side_effect=lambda action: action()): self.pub.exit(self.root)
        def changed(phase):
            if phase == 'before-pointer': return
        original = release.release_barrier
        def new_system(*args):
            original(*args)
            generation = Path(self.temporary.name) / 'generation-2'; generation.mkdir(exist_ok=True)
            self.pub.system.unlink(); self.pub.system.symlink_to(generation)
        with patch.object(release, 'release_barrier', new_system), self.assertRaises(release.Paused): self.upload()
        self.assertFalse((self.root / 'current').exists())
        self.pub.compiled.chmod(0o644)
        data = json.loads(self.pub.compiled.read_text()); data['schema'] = 1
        self.pub.compiled.write_bytes(release.encode(data))
        with self.assertRaisesRegex(release.Rejected, 'Incompatible'): self.pub.policy()


if __name__ == '__main__': unittest.main(verbosity=1)
