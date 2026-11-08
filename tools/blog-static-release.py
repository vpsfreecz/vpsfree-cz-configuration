#!/usr/bin/env python3
"""Validated blog artifacts and operator-installed content publication policy."""
import argparse
from contextlib import contextmanager, nullcontext
from datetime import datetime, timezone
import fcntl
import ctypes
import hashlib
import io
import json
import os
import pwd
from pathlib import Path, PurePosixPath
import re
import stat
import tarfile
import tempfile
import uuid
import zipfile

REPOSITORY = 'vpsfreecz/blog'
WORKFLOW_PATH = '.github/workflows/build.yml'
MAX_BYTES = 512 * 1024 * 1024
COMPILED_POLICY = '@blogPolicy@'
STATE = Path('/var/lib/blog')
CONTROL = Path('/var/lib/blog-control')
RELEASE_KEY = r'[0-9a-f]{40}-[0-9a-f]{16}'


class Paused(ValueError):
    pass


class Rejected(ValueError):
    pass


def require(test, message):
    if not test:
        raise Rejected(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def encode(value):
    return (json.dumps(value, sort_keys=True, indent=2) + '\n').encode()


def safe_path(name):
    p = PurePosixPath(name)
    require(name == p.as_posix() and not p.is_absolute() and '..' not in p.parts
            and '\\' not in name and not any(x.startswith('.') for x in p.parts), 'Unsafe archive path')
    return p


def validate(archive, receipt, trusted):
    """Check package consistency against the authority supplied by the caller."""
    require(type(receipt) is dict and type(trusted) is dict, 'Invalid receipt identity')
    require(len(archive) <= MAX_BYTES, 'Archive too large')
    require(receipt.get('archive_sha256') == digest(archive), 'Archive digest mismatch')
    for key in ('repository', 'source_sha', 'workflow_path', 'run_id', 'run_attempt', 'artifact_name'):
        require(receipt.get(key) == trusted.get(key), 'Artifact identity mismatch: ' + key)
    require(receipt.get('schema') == 1, 'Unsupported receipt schema')
    files, total = {}, 0
    with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
        for item in tar:
            safe_path(item.name)
            require(item.name not in files, 'Duplicate archive entry')
            require(item.isfile(), 'Only regular archive files are allowed')
            total += item.size
            require(total <= MAX_BYTES and len(files) < 25000, 'Expanded artifact too large')
            files[item.name] = tar.extractfile(item).read()
    require('release.json' in files and 'metadata.json' in files, 'Missing artifact metadata')
    release = json.loads(files['release.json'])
    require(release == {k: v for k, v in receipt.items() if k != 'archive_sha256'}, 'Envelope/receipt mismatch')
    require(digest(files['metadata.json']) == receipt.get('metadata_sha256'), 'Metadata hash mismatch')
    metadata = json.loads(files['metadata.json'])
    require(type(metadata) is dict and type(metadata.get('inputs')) is dict, 'Invalid metadata')
    require(metadata.get('schema') == 1 and metadata.get('inputs') == receipt.get('inputs'), 'Input graph mismatch')
    inputs = metadata['inputs']
    require(inputs.get('revision') == trusted['source_sha'] and bool(re.fullmatch(r'[0-9a-f]{40}', inputs.get('revision', ''))), 'Dirty/null/mismatched source')
    require(inputs.get('sourceNarHash') and inputs.get('nixpkgsRevision'), 'Missing pinned build inputs')
    payload = metadata.get('files', {})
    require(type(payload) is dict, 'Invalid file manifest')
    require(set(files) == set(payload) | {'metadata.json', 'release.json'}, 'Undeclared artifact payload')
    for name, expected in payload.items():
        p = safe_path(name)
        require(p.parts[0] in ('cs', 'en') and len(p.parts) > 1, 'Invalid web root')
        require(p.suffix.lower() not in ('.php', '.sql', '.py', '.sh', '.rb', '.env'), 'Executable/private web payload')
        require(digest(files[name]) == expected, 'Web file hash mismatch')
    for language in ('cs', 'en'):
        require({language + '/index.html', language + '/feed/index.xml'} <= files.keys(), 'Missing root/feed')
    return files


def upload_package(bundle):
    """The signed sender is the authority; these are not independent API facts."""
    with zipfile.ZipFile(bundle) as zipped:
        members = zipped.infolist()
        require(len(members) == 2 and set(zipped.namelist()) == {'payload.tar.gz', 'receipt.json'},
                'Expected exactly payload.tar.gz and receipt.json')
        require(sum(m.file_size for m in members) <= MAX_BYTES, 'ZIP expands too large')
        for member in members:
            mode = member.external_attr >> 16
            require(stat.S_IFMT(mode) in (0, stat.S_IFREG) and not member.flag_bits & 1,
                    'Nonregular or encrypted ZIP entry')
            require(member.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED), 'Unsupported ZIP compression')
        require(zipped.getinfo('receipt.json').file_size <= 1024 * 1024, 'Receipt too large')
        receipt = json.loads(zipped.read('receipt.json'))
        archive = zipped.read('payload.tar.gz')
    require(type(receipt) is dict, 'Invalid receipt')
    require(receipt.get('repository') == REPOSITORY and receipt.get('workflow_path') == WORKFLOW_PATH,
            'Wrong repository/workflow')
    require(type(receipt.get('source_sha')) is str and re.fullmatch(r'[0-9a-f]{40}', receipt['source_sha']), 'Invalid source SHA')
    require(all(type(receipt.get(k)) is int and 0 < receipt[k] < 2 ** 63 for k in ('run_id', 'run_attempt')),
            'Invalid run identity')
    require(receipt.get('artifact_name') == 'blog-' + receipt['source_sha'], 'Invalid artifact name')
    return archive, receipt, validate(archive, receipt, receipt)


def content_as_release(operation):
    """Only fixed internal content operations cross this root/service boundary."""
    if os.geteuid() != 0:
        return operation()
    try:
        account = pwd.getpwnam('blog-release')
        groups = sorted(set(os.getgrouplist('blog-release', account.pw_gid)))
    except KeyError:
        raise Rejected('Fixed blog-release account is not installed')
    require(account.pw_uid > 0 and account.pw_gid > 0 and all(g > 0 for g in groups),
            'Invalid fixed blog-release identity')
    read_fd, write_fd = os.pipe2(os.O_CLOEXEC)
    pid = os.fork()
    if pid == 0:
        os.close(read_fd)
        try:
            libc = ctypes.CDLL(None, use_errno=True)
            # No retained capabilities or saved root identity may survive.
            require(libc.prctl(8, 0, 0, 0, 0) == 0, 'Cannot disable retained capabilities')
            os.setgroups(groups)
            os.setresgid(account.pw_gid, account.pw_gid, account.pw_gid)
            os.setresuid(account.pw_uid, account.pw_uid, account.pw_uid)
            class Header(ctypes.Structure):
                _fields_ = [('version', ctypes.c_uint32), ('pid', ctypes.c_int)]
            class Caps(ctypes.Structure):
                _fields_ = [('effective', ctypes.c_uint32), ('permitted', ctypes.c_uint32),
                            ('inheritable', ctypes.c_uint32)]
            require(libc.capset(ctypes.byref(Header(0x20080522, 0)), (Caps * 2)()) == 0,
                    'Cannot clear content capabilities')
            require(libc.prctl(38, 1, 0, 0, 0) == 0, 'Cannot forbid privilege regain')
            require(os.getresuid() == (account.pw_uid,) * 3
                    and os.getresgid() == (account.pw_gid,) * 3, 'Privilege drop incomplete')
            response = {'ok': True, 'value': operation()}
        except BaseException as error:
            response = {'ok': False, 'reason': str(error) if type(error) in (Rejected, Paused)
                        else 'Unprivileged content operation failed'}
        payload = encode(response)
        if len(payload) > 65536:
            payload = encode({'ok': False, 'reason': 'Content result exceeds fixed bound'})
        try:
            view = memoryview(payload)
            while view:
                view = view[os.write(write_fd, view):]
        finally:
            os.close(write_fd)
            os._exit(0)
    os.close(write_fd)
    output = bytearray()
    try:
        while True:
            chunk = os.read(read_fd, 8192)
            if not chunk:
                break
            output.extend(chunk)
            require(len(output) <= 65536, 'Content result exceeds fixed bound')
    finally:
        os.close(read_fd)
        _, status = os.waitpid(pid, 0)
    require(os.WIFEXITED(status) and os.WEXITSTATUS(status) == 0, 'Content child failed')
    response = json.loads(output)
    require(response.get('ok') is True, response.get('reason', 'Content child failed'))
    return response['value']


def durable_file(path, data, mode=0o444):
    with path.open('wb') as target:
        target.write(data)
        os.fchmod(target.fileno(), mode)
        target.flush()
        os.fsync(target.fileno())


def sync_tree(tree):
    """Durability barrier for new and older validated schema-1 release trees."""
    require(tree.is_dir() and not tree.is_symlink(), 'Invalid durability root')
    directories = [tree]
    for path in tree.rglob('*'):
        require(not path.is_symlink(), 'Cannot sync a retained symlink')
        if path.is_dir():
            directories.append(path)
        else:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
            try:
                require(stat.S_ISREG(os.fstat(fd).st_mode), 'Nonregular retained file')
                os.fsync(fd)
            finally:
                os.close(fd)
    for path in sorted(directories, key=lambda p: len(p.parts), reverse=True):
        sync_directory(path)


def release_barrier(root, key):
    sync_tree(root / 'releases' / key)
    fd = os.open(root / 'releases' / (key + '.tar.gz'), os.O_RDONLY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)
    sync_directory(root / 'releases')
    sync_directory(root)


def atomic_json(path, data):
    temporary = path.with_name(path.name + '.new')
    with temporary.open('wb') as target:
        target.write(encode(data))
        target.flush()
        os.fsync(target.fileno())
    os.replace(temporary, path)
    sync_directory(path.parent)


def sync_directory(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


@contextmanager
def serialized(root):
    root.mkdir(parents=True, exist_ok=True)
    with (root / 'transaction.lock').open('a') as lock:
        # This is filesystem serialization, NEVER machine ownership/admission.
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def stage(root, archive, receipt, files, authority):
    key = receipt['source_sha'] + '-' + receipt['archive_sha256'][:16]
    for name in ('releases', 'receipts', 'assets'):
        (root / name).mkdir(parents=True, exist_ok=True)
    release = root / 'releases' / key
    archive_path = root / 'releases' / (key + '.tar.gz')
    with serialized(root):
        if release.exists():
            require(not release.is_symlink(), 'Release path is a symlink')
            require(archive_path.exists() and digest(archive_path.read_bytes()) == receipt['archive_sha256'], 'Retained release/archive conflict')
            check_tree(release, files)
            release_barrier(root, key)
            retained = root / 'receipts' / (key + '.json')
            if not retained.exists():
                atomic_json(retained, {**receipt, 'authority': authority, 'release': key})
            else:
                record, _ = retained_release(root, key)
                require(all(record.get(k) == v for k, v in receipt.items()), 'Retained receipt conflict')
            return key
        with tempfile.TemporaryDirectory(prefix='.incoming-', dir=root / 'releases') as temporary:
            staging = Path(temporary) / 'tree'
            staging.mkdir()
            for name, value in files.items():
                p = staging / name
                p.parent.mkdir(parents=True, exist_ok=True)
                durable_file(p, value)
            for p in staging.rglob('*'):
                if p.is_dir():
                    p.chmod(0o755)
            if archive_path.exists():
                require(digest(archive_path.read_bytes()) == receipt['archive_sha256'], 'Retained archive conflict')
            else:
                durable_file(archive_path, archive)
            staging.chmod(0o755)
            sync_tree(staging)
            # An existing archive may come from an older stage-only helper.
            fd = os.open(archive_path, os.O_RDONLY | os.O_NOFOLLOW)
            try:
                os.fsync(fd)
            finally:
                os.close(fd)
            os.replace(staging, release)
            sync_directory(root / 'releases')
            sync_directory(root)
        atomic_json(root / 'receipts' / (key + '.json'), {**receipt, 'authority': authority, 'release': key})
        sync_directory(root / 'releases')
    return key


def check_tree(tree, files):
    require(tree.is_dir() and not tree.is_symlink(), 'Missing retained release')
    found = set()
    for path in tree.rglob('*'):
        require(not path.is_symlink(), 'Retained release contains a symlink')
        if path.is_file():
            name = path.relative_to(tree).as_posix()
            require(name in files and digest(path.read_bytes()) == digest(files[name]), 'Retained release corruption')
            found.add(name)
        else:
            require(path.is_dir(), 'Retained release contains a nonregular file')
    require(found == set(files), 'Retained release file set mismatch')


def retained_release(root, key):
    require(type(key) is str and re.fullmatch(RELEASE_KEY, key), 'Invalid retained release key')
    receipt_path = root / 'receipts' / (key + '.json')
    archive_path = root / 'releases' / (key + '.tar.gz')
    require(not receipt_path.is_symlink() and not archive_path.is_symlink(), 'Retained metadata symlink')
    record = json.loads(receipt_path.read_text())
    require(record.get('release') == key and key == record['source_sha'] + '-' + record['archive_sha256'][:16], 'Retained identity mismatch')
    archive = archive_path.read_bytes()
    original = {k: v for k, v in record.items() if k not in ('api_facts', 'authority', 'release')}
    files = validate(archive, original, record)
    check_tree(root / 'releases' / key, files)
    return record, files


def current_state(root):
    link = root / 'current'
    require(not link.exists() or link.is_symlink(), 'Current is not a symlink')
    current = os.readlink(link) if link.is_symlink() else None
    path = root / 'receipts/current.json'
    require(not path.is_symlink(), 'Current receipt is a symlink')
    data = json.loads(path.read_text()) if path.exists() else None
    require((current is None and data is None) or (data is not None and current == 'releases/' + data['release']), 'Pointer/receipt need reconciliation')
    return current, data, digest(path.read_bytes()) if path.exists() else None


def upload_floor(root):
    path = root / 'receipts/upload-order.json'
    if not path.exists():
        return None
    require(not path.is_symlink(), 'Ordering state symlink')
    data = json.loads(path.read_text())
    require(data.get('schema') == 2 and all(type(data.get(k)) is int and 0 < data[k] < 2 ** 63
            for k in ('run_number', 'run_attempt', 'run_id')), 'Invalid upload ordering state')
    require(all(type(data.get(k)) is str and re.fullmatch(pattern, data[k]) for k, pattern in (
        ('source_sha', r'[0-9a-f]{40}'), ('body_sha256', r'[0-9a-f]{64}'),
        ('release', RELEASE_KEY))), 'Invalid upload ordering binding')
    return data


def persist_floor(root, value):
    if value is None:
        return
    prior = upload_floor(root)
    require(prior is None or (value['run_number'], value['run_attempt']) >=
            (prior['run_number'], prior['run_attempt']), 'Ordering floor regression')
    if prior and value['run_number'] == prior['run_number']:
        require(all(value[k] == prior[k] for k in ('run_id', 'source_sha')), 'Run identity conflict')
        if value['run_attempt'] == prior['run_attempt']:
            require(value == prior, 'Ordering binding conflict')
    atomic_json(root / 'receipts/upload-order.json', value)


def reconcile(root):
    pending = root / 'receipts/pending.json'
    if not pending.exists():
        current_state(root)
        return
    require(not pending.is_symlink(), 'Pending receipt symlink')
    data = json.loads(pending.read_text())
    retained_release(root, data['release'])
    release_barrier(root, data['release'])
    sync_tree(root / 'assets')
    require(re.fullmatch(r'[0-9a-f-]{36}', data['transaction_id']), 'Invalid transaction identity')
    old_pointer = data.get('old_pointer')
    require(old_pointer is None or re.fullmatch('releases/' + RELEASE_KEY, old_pointer), 'Invalid prior pointer')
    link = root / 'current'
    require(not link.exists() or link.is_symlink(), 'Current is not a symlink')
    current = os.readlink(link) if link.is_symlink() else None
    if current == 'releases/' + data['release']:
        atomic_json(root / 'receipts/current.json', data)
        persist_floor(root, data.get('upload_floor'))
        data['outcome'] = 'reconciled-activated'
    elif current == data['old_pointer']:
        current_state(root)
        data['outcome'] = 'reconciled-before-switch'
    else:
        raise Rejected('Uncertain pointer; operator reconciliation required')
    temporary = root / 'current.new'
    if temporary.exists() or temporary.is_symlink():
        require(temporary.is_symlink() and os.readlink(temporary) == 'releases/' + data['release'], 'Uncertain temporary pointer')
        temporary.unlink()
    atomic_json(root / 'receipts' / (data['transaction_id'] + '.json'), data)
    pending.unlink()
    sync_directory(pending.parent)


def _switch(root, key, admit, expected_previous, rollback=False, interrupt=None, lock=None, policy_identity=None, upload=None):
    """One serialized transaction; production authority is rechecked at commit."""
    with (lock or (lambda: serialized(root)))():
        reconcile(root)
        old, previous, previous_hash = current_state(root)
        require(previous_hash == expected_previous, 'Previous receipt changed; stale/concurrent request')
        require(admit() is True, 'Publication policy refused')
        record, files = retained_release(root, key)
        release_barrier(root, key)
        # Cached pages may keep referencing old fingerprinted CSS after a switch.
        css = {}
        for name, value in files.items():
            parts = PurePosixPath(name).parts
            if len(parts) >= 3 and parts[0] in ('cs', 'en') and parts[1] == 'css':
                require(bool(re.search(r'\.[0-9a-f]{16,}\.css$', name)), 'CSS namespace must be fingerprinted')
                relative = PurePosixPath(*parts[1:]).as_posix()
                require(relative not in css or css[relative] == value, 'Cross-language immutable CSS conflict')
                p = root / 'assets' / relative
                require(not p.exists() or p.read_bytes() == value, 'Immutable CSS path reuse')
                css[relative] = value
        # Legacy paths are immutable too, including their bytes across languages/releases.
        if previous:
            old_metadata = json.loads((root / 'releases' / previous['release'] / 'metadata.json').read_text())
            new_metadata = json.loads(files['metadata.json'])
            old_uploads = {p: v for p, v in old_metadata['files'].items() if '/wp-content/uploads/' in p}
            require(old_uploads.keys() <= new_metadata['files'].keys(), 'Legacy upload path removed')
            for name, value in new_metadata['files'].items():
                if '/wp-content/uploads/' in name and name in old_metadata['files']:
                    require(old_metadata['files'][name] == value, 'Legacy upload path byte conflict')
        for name, value in css.items():
            p = root / 'assets' / name
            p.parent.mkdir(parents=True, exist_ok=True)
            for parent in [p.parent, *p.parent.parents]:
                if parent == root / 'assets':
                    break
                parent.chmod(0o755)
            if not p.exists():
                durable_file(p, value)
        # Retained fallback assets must be durable before any pointer receipt.
        sync_tree(root / 'assets')
        sync_directory(root)
        if old == 'releases/' + key and upload is None and not rollback:
            return {**previous, 'outcome': 'unchanged'}
        transaction = {**record, 'transaction_id': str(uuid.uuid4()), 'release': key,
                       'previous_release': previous['release'] if previous else None,
                       'previous_receipt_sha256': previous_hash, 'old_pointer': old,
                       'outcome': 'rollback' if rollback else 'activated',
                       'at': datetime.now(timezone.utc).isoformat()}
        # Validation/copying can take time; recheck external authority at the
        # commit boundary rather than relying on the earlier preparation check.
        require(admit() is True, 'Publication policy refused at switch')
        require(current_state(root)[2] == expected_previous, 'Previous receipt changed at switch')
        if policy_identity:
            transaction['publication'] = policy_identity()
        transaction['upload_floor'] = upload or upload_floor(root)
        if upload:
            transaction['upload'] = upload
        atomic_json(root / 'receipts/pending.json', transaction)
        if interrupt:
            interrupt('before-pointer')
        temporary = root / 'current.new'
        require(not temporary.exists() and not temporary.is_symlink(), 'Uncertain temporary pointer')
        temporary.symlink_to('releases/' + key)
        os.replace(temporary, root / 'current')
        sync_directory(root)
        if interrupt:
            interrupt('after-pointer')
        atomic_json(root / 'receipts/current.json', transaction)
        persist_floor(root, transaction['upload_floor'])
        atomic_json(root / 'receipts' / (transaction['transaction_id'] + '.json'), transaction)
        (root / 'receipts/pending.json').unlink()
        sync_directory(root / 'receipts')
    return transaction


class Publication:
    """Fixed target policy, separate from workspace deployment/session ownership.

    Paths/UID can be injected only by local Python fixtures, never by the CLI.
    """
    def __init__(self, compiled=COMPILED_POLICY, active='/etc/blog-release-policy.json',
                 system='/run/current-system', control=CONTROL, owner=0, state=STATE):
        self.compiled = Path(compiled)
        self.active = Path(active)
        self.system = Path(system)
        self.started_system = str(self.system.resolve())
        self.control = Path(control)
        self.owner = owner
        self.root = Path(state)

    def policy(self, enabled=True):
        require(self.compiled.is_absolute() and self.compiled.is_file(), 'Installed publication policy unavailable')
        require(self.active.resolve(strict=True) == self.compiled.resolve(strict=True), 'Publication policy changed; use selected helper')
        require(self.compiled.stat().st_uid == self.owner and not self.compiled.stat().st_mode & 0o022,
                'Publication policy must be immutable and root-owned')
        data = json.loads(self.compiled.read_text())
        require(data.get('schema') == 2 and data.get('authority') == 'hmac-upload-v1'
                and data.get('repository') == REPOSITORY and data.get('workflow_path') == WORKFLOW_PATH
                and data.get('state_dir') == str(STATE) and type(data.get('enabled')) is bool,
                'Incompatible publication policy')
        if enabled:
            require(data['enabled'], 'Upload publication disabled')
        return data

    def identity(self):
        self.policy()
        selected = self.system.resolve(strict=True)
        require(selected.is_dir(), 'Unknown selected system')
        if str(selected) != self.started_system:
            raise Paused('Selected system changed; use the new selected helper')
        return {'policy_sha256': digest(self.compiled.read_bytes()), 'system': str(selected)}

    @contextmanager
    def lock(self):
        info = self.control.lstat()
        require(stat.S_ISDIR(info.st_mode) and info.st_uid == self.owner and not info.st_mode & 0o022,
                'Unsafe root-owned publication control directory')
        fd = os.open(self.control / 'transaction.lock', os.O_RDWR | os.O_NOFOLLOW)
        with os.fdopen(fd, 'r+') as stream:
            info = os.fstat(stream.fileno())
            require(stat.S_ISREG(info.st_mode) and info.st_uid == self.owner and not info.st_mode & 0o007,
                    'Unsafe stable publication lock')
            fcntl.flock(stream, fcntl.LOCK_EX)
            yield

    def control_state(self):
        path = self.control / 'state.json'
        if not path.exists():
            return {'schema': 2, 'paused': True}
        info = path.lstat()
        require(stat.S_ISREG(info.st_mode) and info.st_uid == self.owner and not info.st_mode & 0o022,
                'Unsafe root-owned control state')
        data = json.loads(path.read_text())
        require(data.get('schema') == 2 and type(data.get('paused')) is bool, 'Incompatible control state; publication paused')
        return data

    def allowed(self):
        identity = self.identity()
        control = self.control_state()
        if control['paused'] or any(control.get(k) != v for k, v in identity.items()):
            raise Paused('Publication paused; verify selected system and run maintenance-exit')
        return True

    def status(self):
        result = {}
        try:
            data = self.policy(enabled=False)
            if not data['enabled']:
                return {'mode': 'disabled'}
            with self.lock():
                result = content_as_release(lambda: content_status(self.root))
                self.allowed()
            return {'mode': 'resumed', **self.identity(), **result}
        except (Paused, Rejected, OSError, ValueError) as error:
            reason = str(error) if isinstance(error, (Paused, Rejected)) else 'Unreadable publication/control state'
            return {'mode': 'paused', 'reason': reason, **result}

    def pause_locked(self):
        require(os.geteuid() == 0, 'Maintenance and rollback require root')
        atomic_json(self.control / 'state.json', {'schema': 2, 'paused': True})
        (self.control / 'state.json').chmod(0o640)
        os.chown(self.control / 'state.json', self.owner, self.control.stat().st_gid)

    def enter(self):
        with self.lock():
            self.pause_locked()
        return {'mode': 'paused'}

    def exit(self, root):
        require(os.geteuid() == 0, 'Maintenance and rollback require root')
        with self.lock():
            self.pause_locked()
            identity = self.identity()
            content_as_release(lambda: reconcile_content(root))
            atomic_json(self.control / 'state.json', {'schema': 2, 'paused': False, **identity})
            (self.control / 'state.json').chmod(0o640)
            os.chown(self.control / 'state.json', self.owner, self.control.stat().st_gid)
        return {'mode': 'resumed', **identity}

    def rollback(self, root, key, expected_previous, interrupt=None):
        self.policy()
        require(root == self.root, 'Publication root conflicts with installed policy')
        require(os.geteuid() == 0, 'Maintenance and rollback require root')
        with self.lock():
            self.pause_locked()
            def authority():
                self.identity()
                require(self.control_state()['paused'], 'Rollback requires maintenance pause')
                return True
            return content_as_release(lambda: _switch(
                root, key, authority, expected_previous, rollback=True, interrupt=interrupt,
                lock=nullcontext, policy_identity=self.identity))

    def upload(self, bundle, run_number, body_sha256, interrupt=None):
        require(os.geteuid() != 0, 'Upload content must run as blog-release')
        self.allowed()
        archive, receipt, files = upload_package(bundle)
        key = receipt['source_sha'] + '-' + receipt['archive_sha256'][:16]
        binding = {'schema': 2, 'run_number': run_number, 'run_attempt': receipt['run_attempt'],
                   'run_id': receipt['run_id'], 'source_sha': receipt['source_sha'],
                   'body_sha256': body_sha256, 'release': key}
        require(type(run_number) is int and 0 < run_number < 2 ** 63, 'Invalid run number')
        require(type(body_sha256) is str and re.fullmatch(r'[0-9a-f]{64}', body_sha256), 'Invalid body digest')

        def check_order():
            floor = upload_floor(self.root)
            if not floor:
                return False
            order = (run_number, receipt['run_attempt'])
            require(order >= (floor['run_number'], floor['run_attempt']), 'Superseded upload')
            if run_number == floor['run_number']:
                require(all(binding[k] == floor[k] for k in ('run_id', 'source_sha')), 'Run identity conflict')
            if order == (floor['run_number'], floor['run_attempt']):
                require(binding == floor, 'Conflicting upload retry')
                _, current, _ = current_state(self.root)
                require(current and current.get('upload') == binding and current['release'] == key,
                        'Upload no longer selected; rollback or supersession')
                retained_release(self.root, key)
                return True
            return False

        with self.lock():
            self.allowed()
            reconcile(self.root)
            duplicate = check_order()
        if not duplicate:
            stage(self.root, archive, receipt, files, {'kind': 'hmac-upload-v1'})
        with self.lock():
            self.allowed()
            reconcile(self.root)
            if not check_order():
                previous = current_state(self.root)[2]
                _switch(self.root, key, self.allowed, previous,
                        lock=nullcontext, policy_identity=self.identity, upload=binding, interrupt=interrupt)
            _, current, current_hash = current_state(self.root)
            require(current.get('upload') == binding, 'Upload selection changed')
            return {'selected': True, 'source_sha': receipt['source_sha'], 'release': key,
                    'receipt_sha256': current_hash, 'body_sha256': body_sha256,
                    'run_number': run_number, 'run_id': receipt['run_id'], 'run_attempt': receipt['run_attempt']}


def content_status(root):
    _, current, receipt_hash = current_state(root)
    if current:
        retained_release(root, current['release'])
    return {'current_release': current['release'] if current else None,
            'current_receipt_sha256': receipt_hash, 'upload_floor': upload_floor(root)}


def reconcile_content(root):
    reconcile(root)
    content_status(root)
    return True


def check_maintenance():
    """Native NixOS pre-switch gate, including a candidate disabling publication."""
    if not CONTROL.exists():
        prior = [STATE / 'current', STATE / 'receipts/current.json', STATE / 'receipts/pending.json']
        if STATE.exists():
            require(content_as_release(lambda: not any(p.exists() or p.is_symlink() for p in prior)),
                    'Existing publication needs maintenance-enter')
        return
    publication = Publication()
    with publication.lock():
        require(publication.control_state()['paused'], 'Run maintenance-enter before system switch')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['rollback', 'maintenance-enter', 'maintenance-exit', 'status', 'check-maintenance'])
    parser.add_argument('--release')
    parser.add_argument('--expected-current', help='Exact current receipt SHA256, or none for first activation')
    options = parser.parse_args()
    publication = Publication()
    if options.command == 'check-maintenance':
        check_maintenance()
        return
    if options.command == 'rollback':
        require(options.release is not None and options.expected_current is not None, 'Exact release and expected-current receipt required')
        previous = None if options.expected_current == 'none' else options.expected_current
        require(previous is None or re.fullmatch(r'[0-9a-f]{64}', previous), 'Invalid expected-current receipt')
        result = publication.rollback(STATE, options.release, previous)
    else:
        result = {'maintenance-enter': publication.enter,
                  'maintenance-exit': lambda: publication.exit(STATE),
                  'status': publication.status}[options.command]()
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except (Rejected, Paused) as error:
        raise SystemExit('Blog release rejected: ' + str(error))
    except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile):
        raise SystemExit('Blog release rejected; current serving is unchanged or needs receipt reconciliation. Inspect local status.')
