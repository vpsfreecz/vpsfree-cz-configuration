"""Disposable filesystem tests for the host's destructive retention policy."""

import fcntl
import importlib.util
import os
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch


SOURCE = Path(os.environ.get('CLEANUP_TEST_SOURCE', str(Path(__file__).resolve().parents[1] / 'cluster/cz.vpsfree/machines/aitherdev/nix-store-cleanup.py')))
SPEC = importlib.util.spec_from_file_location('cleanup', SOURCE)
cleanup = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(cleanup)


class RetentionTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cleanup-policy-', dir='/tmp')
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.store = self.base / 'store'
        self.store.mkdir()
        self.output = self.store / 'test.json'
        self.output.write_text('{}')
        self.run = self.base / 'os-test-policy'
        self.run.mkdir()
        (self.run / 'config.json').symlink_to(self.output)
        (self.run / '.lock').touch()
        (self.run / 'test-result.txt').write_text('expected_success\n')
        (self.run / 'services-root.img').write_bytes(b'disposable guest data')
        self.root = self.base / 'registered-root'
        self.root.symlink_to(self.run / 'config.json')
        self.cutoff = time.time() + 1
        self.addCleanup(patch.stopall)
        patch.object(cleanup, 'STORE', self.store).start()
        patch.object(cleanup, 'process_uses', return_value=False).start()

    def action(self):
        return cleanup.root_action(self.root, self.cutoff, True)

    def test_completed_run_removal_releases_disks_and_root_but_keeps_store(self):
        action = self.action()
        self.assertIsNotNone(action)
        cleanup.remove_root(action)
        self.assertFalse(self.run.exists())
        self.assertFalse(self.root.is_symlink())
        self.assertEqual(self.output.read_text(), '{}')

    def test_recent_or_incomplete_runs_are_preserved(self):
        self.assertIsNone(cleanup.root_action(self.root, time.time() - 7 * 86400, True))
        (self.run / 'test-result.txt').unlink()
        self.assertIsNone(self.action())

    def test_all_native_terminal_result_states_are_collectible(self):
        for result in ['expected_success', 'unexpected_success', 'expected_failure', 'unexpected_failure']:
            (self.run / 'test-result.txt').write_text(result + '\n')
            self.assertIsNotNone(self.action(), result)

    def test_hold_on_run_or_its_parent_preserves_it(self):
        for directory in [self.run, self.base]:
            hold = directory / '.keep'
            hold.touch()
            self.assertIsNone(self.action())
            hold.unlink()

    def test_running_lock_and_process_references_each_preserve_run(self):
        with (self.run / '.lock').open('rb') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertIsNone(self.action())
        with patch.object(cleanup, 'process_uses', return_value=True):
            self.assertIsNone(self.action())

    def test_changed_data_or_new_process_stops_apply(self):
        action = self.action()
        (self.run / 'services-root.img').write_text('new data')
        with self.assertRaisesRegex(RuntimeError, 'changed or became active'):
            cleanup.remove_root(action)
        action = self.action()
        with patch.object(cleanup, 'process_uses', return_value=True):
            with self.assertRaisesRegex(RuntimeError, 'changed or became active'):
                cleanup.remove_root(action)
        self.assertTrue(self.root.is_symlink())

    def test_external_symlink_targets_survive_tree_removal(self):
        external = self.base / 'other-session'
        external.mkdir()
        (external / 'important').write_text('retain')
        (self.run / 'external').symlink_to(external, target_is_directory=True)
        cleanup.remove_root(self.action())
        self.assertEqual((external / 'important').read_text(), 'retain')

    def test_unknown_layout_and_disabled_test_cleanup_are_preserved(self):
        (self.run / '.lock').unlink()
        self.assertIsNone(self.action())
        self.assertIsNone(cleanup.root_action(self.root, self.cutoff, False))

    def test_dangling_registration_removal_does_not_remove_its_parent(self):
        self.root.unlink()
        self.root.symlink_to(self.base / 'missing')
        cleanup.remove_root(self.action())
        self.assertTrue(self.run.exists())

    def test_symlinked_run_ancestors_are_not_cleanup_authority(self):
        alias = self.base / 'alias'
        alias.symlink_to(self.base, target_is_directory=True)
        self.root.unlink()
        self.root.symlink_to(alias / self.run.name / 'config.json')
        self.assertIsNone(self.action())
        self.assertTrue(self.run.is_dir())

    def test_generation_retention_respects_rollback_and_running_system(self):
        profile = self.base / 'system'
        generations = {}
        for number in range(1, 7):
            path = self.base / f'system-{number}-link'
            path.symlink_to(self.output)
            generations[number] = path
        profile.symlink_to('system-4-link')
        self.assertEqual(cleanup.profile_plan(profile, generations, self.cutoff, 2, set()), [1, 2])
        self.assertEqual(cleanup.profile_plan(profile, generations, self.cutoff, 2, {self.output}), [])


class ProcessReferenceTest(unittest.TestCase):
    def test_own_lock_is_ignored_but_other_descriptors_and_cwd_are_not(self):
        with tempfile.TemporaryDirectory() as directory:
            base = Path(directory)
            proc = base / 'proc'
            process = proc / str(os.getpid())
            (process / 'fd').mkdir(parents=True)
            run = base / 'os-test-process'
            run.mkdir()
            (process / 'fd/9').symlink_to(run / '.lock')
            with patch.object(cleanup, 'PROC', proc):
                self.assertFalse(cleanup.process_uses(run, 9))
                (process / 'fd/10').symlink_to(run / 'guest.img')
                self.assertTrue(cleanup.process_uses(run, 9))
                (process / 'fd/10').unlink()
                (process / 'cwd').symlink_to(run)
                self.assertTrue(cleanup.process_uses(run, 9))


if __name__ == '__main__':
    unittest.main()
