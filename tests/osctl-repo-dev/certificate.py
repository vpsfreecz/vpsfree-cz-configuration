"""Exercise only disposable leaf/CA data; no host CA or service is accessed."""

import grp
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "cluster/cz.vpsfree/machines/aitherdev/osctl-repo-dev-certificate.bash"
HOST = "images.aitherdev.int.vpsfree.cz"


class CertificateTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="repo-leaf-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.ca = self.root / "pki"
        self.authority = self.ca / "authority"
        self.authority.mkdir(parents=True, mode=0o700)
        self.tls = self.root / "repo-tls"
        self.lock = self.root / "substrate.lock"
        self.group = grp.getgrgid(os.getgid()).gr_name
        self.openssl("genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256", "-out", str(self.authority / "ca-key.pem"))
        (self.authority / "ca-key.pem").chmod(0o600)
        self.openssl("req", "-x509", "-new", "-days", "365", "-key", str(self.authority / "ca-key.pem"),
                     "-subj", "/CN=Disposable test CA", "-addext", "basicConstraints=critical,CA:TRUE,pathlen:0",
                     "-addext", "keyUsage=critical,keyCertSign,cRLSign", "-out", str(self.authority / "ca.pem"))
        (self.authority / "ca.pem").chmod(0o644)
        self.ca_before = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in self.authority.iterdir()}

    def openssl(self, *args):
        return subprocess.run(["openssl", *args], check=True, capture_output=True, text=True).stdout

    def reconcile(self, ok=True):
        result = subprocess.run(["bash", str(SOURCE), str(self.ca), str(self.tls), str(self.lock), self.group,
                                 HOST, "90", "2592000"], capture_output=True, text=True, timeout=10)
        if ok:
            self.assertEqual(result.returncode, 0, result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0)
        return result

    def test_exact_san_atomic_pair_and_idempotent_reuse(self):
        self.assertEqual(self.reconcile().stdout.strip(), "changed")
        first = os.readlink(self.tls / "current")
        self.assertTrue(first.startswith("pairs/pair-"))
        pair = self.tls / first
        names = self.openssl("x509", "-noout", "-ext", "subjectAltName", "-in", str(pair / "server.pem"))
        self.assertEqual(names.splitlines()[1].strip(), "DNS:" + HOST)
        self.assertEqual((pair / "server-key.pem").stat().st_mode & 0o777, 0o640)
        self.assertEqual(self.reconcile().stdout.strip(), "unchanged")
        self.assertEqual(os.readlink(self.tls / "current"), first)
        self.assertEqual({p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in self.authority.iterdir()}, self.ca_before)

    def test_invalid_pair_is_replaced_without_touching_ca(self):
        self.reconcile()
        first = os.readlink(self.tls / "current")
        pair = self.tls / first
        self.openssl("genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256", "-out", str(pair / "server-key.pem"))
        (pair / "server-key.pem").chmod(0o640)
        self.assertEqual(self.reconcile().stdout.strip(), "changed")
        self.assertNotEqual(os.readlink(self.tls / "current"), first)
        self.assertTrue(pair.is_dir())
        self.assertEqual({p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in self.authority.iterdir()}, self.ca_before)

    def test_missing_or_mismatched_ca_never_creates_or_selects_a_leaf(self):
        self.reconcile()
        current = os.readlink(self.tls / "current")
        (self.authority / "ca-key.pem").unlink()
        self.reconcile(ok=False)
        self.assertEqual(os.readlink(self.tls / "current"), current)
        self.openssl("genpkey", "-algorithm", "EC", "-pkeyopt", "ec_paramgen_curve:P-256", "-out", str(self.authority / "ca-key.pem"))
        (self.authority / "ca-key.pem").chmod(0o600)
        self.reconcile(ok=False)
        self.assertEqual(os.readlink(self.tls / "current"), current)

    def test_current_cannot_escape_its_pair_directory(self):
        self.reconcile()
        (self.tls / "current").unlink()
        (self.tls / "current").symlink_to(self.authority)
        self.reconcile(ok=False)
        self.assertEqual(os.readlink(self.tls / "current"), str(self.authority))


if __name__ == "__main__":
    unittest.main()
