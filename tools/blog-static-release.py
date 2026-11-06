#!/usr/bin/env python3
"""Site-specific immutable artifact staging. Production activation is fenced."""
import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import tarfile
import tempfile
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, build_opener, HTTPRedirectHandler
import uuid
import zipfile

REPOSITORY = 'vpsfreecz/blog'
WORKFLOW_PATH = '.github/workflows/build.yml'
MAX_BYTES = 512 * 1024 * 1024


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
    """trusted comes from independently checked API facts, never payload strings."""
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
    require(metadata.get('schema') == 1 and metadata.get('inputs') == receipt.get('inputs'), 'Input graph mismatch')
    inputs = metadata['inputs']
    require(inputs.get('revision') == trusted['source_sha'] and bool(re.fullmatch(r'[0-9a-f]{40}', inputs.get('revision', ''))), 'Dirty/null/mismatched source')
    require(inputs.get('sourceNarHash') and inputs.get('nixpkgsRevision'), 'Missing pinned build inputs')
    payload = metadata.get('files', {})
    require(set(files) == set(payload) | {'metadata.json', 'release.json'}, 'Undeclared artifact payload')
    for name, expected in payload.items():
        p = safe_path(name)
        require(p.parts[0] in ('cs', 'en') and len(p.parts) > 1, 'Invalid web root')
        require(p.suffix.lower() not in ('.php', '.sql', '.py', '.sh', '.rb', '.env'), 'Executable/private web payload')
        require(digest(files[name]) == expected, 'Web file hash mismatch')
    for language in ('cs', 'en'):
        require({language + '/index.html', language + '/feed/index.xml'} <= files.keys(), 'Missing root/feed')
    return files


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        return None


class GitHub:
    def __init__(self, token):
        self.token = token

    def api(self, route):
        require(route.startswith('/repos/' + REPOSITORY + '/'), 'Unexpected API repository')
        request = Request('https://api.github.com' + route,
                          headers={'Accept': 'application/vnd.github+json', 'Authorization': 'Bearer ' + self.token,
                                   'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'vpsfree-blog-release'})
        with build_opener(NoRedirect()).open(request, timeout=30) as response:
            return json.load(response)

    def artifact(self, artifact_id):
        request = Request(f'https://api.github.com/repos/{REPOSITORY}/actions/artifacts/{artifact_id}/zip',
                          headers={'Authorization': 'Bearer ' + self.token, 'User-Agent': 'vpsfree-blog-release'})
        try:
            build_opener(NoRedirect()).open(request, timeout=30)
        except HTTPError as error:
            require(error.code in (301, 302, 303, 307, 308), 'Artifact download unavailable')
            location = error.headers.get('Location', '')
        else:
            raise Rejected('Expected signed artifact download redirect')
        host = urlsplit(location).hostname or ''
        require(urlsplit(location).scheme == 'https' and
                (host.endswith('.blob.core.windows.net') or host.endswith('.githubusercontent.com')),
                'Unexpected artifact download origin')
        # Never forward the GitHub bearer credential to signed storage URLs.
        with build_opener(NoRedirect()).open(Request(location, headers={'User-Agent': 'vpsfree-blog-release'}), timeout=30) as response:
            payload = response.read(MAX_BYTES + 1)
        require(len(payload) <= MAX_BYTES, 'Downloaded artifact too large')
        return payload


def protected_head(api):
    branch = api.api('/repos/' + REPOSITORY + '/branches/main')
    require(branch.get('protected') is True, 'Publication main must be protected')
    sha = branch.get('commit', {}).get('sha', '')
    require(bool(re.fullmatch(r'[0-9a-f]{40}', sha)), 'Invalid protected-main identity')
    return sha


def acquire(api, workflow_id):
    require(workflow_id > 0, 'Verified workflow ID is required')
    sha = protected_head(api)
    runs = api.api(f'/repos/{REPOSITORY}/actions/workflows/{workflow_id}/runs?branch=main&head_sha={sha}&status=success&per_page=100')['workflow_runs']
    eligible = [r for r in runs if r.get('head_sha') == sha and r.get('head_branch') == 'main'
                and r.get('workflow_id') == workflow_id and r.get('path') == WORKFLOW_PATH
                and r.get('event') in ('push', 'workflow_dispatch') and r.get('status') == 'completed'
                and r.get('conclusion') == 'success' and r.get('repository', {}).get('full_name') == REPOSITORY
                and r.get('head_repository', {}).get('full_name') == REPOSITORY]
    require(eligible, 'No trusted successful build for exact current SHA ' + sha)
    run = max(eligible, key=lambda r: (r['id'], r.get('run_attempt', 1)))
    artifacts = api.api(f'/repos/{REPOSITORY}/actions/runs/{run["id"]}/artifacts?per_page=100')['artifacts']
    matching = [a for a in artifacts if a.get('name') == 'blog-' + sha and not a.get('expired')]
    require(len(matching) == 1, 'Missing/expired exact artifact for SHA ' + sha + '; rebuild this SHA, no older fallback')
    artifact = matching[0]
    zipped = api.artifact(artifact['id'])
    if artifact.get('digest'):
        require(artifact['digest'] == 'sha256:' + digest(zipped), 'GitHub artifact digest mismatch')
    with zipfile.ZipFile(io.BytesIO(zipped)) as bundle:
        require(len(bundle.infolist()) == 2 and set(bundle.namelist()) == {'payload.tar.gz', 'receipt.json'}, 'Unexpected Actions artifact files')
        require(sum(x.file_size for x in bundle.infolist()) <= MAX_BYTES, 'Actions artifact expands too large')
        for member in bundle.infolist():
            require((member.external_attr >> 16) & 0o170000 not in (0o120000, 0o060000), 'Nonregular ZIP entry')
        archive = bundle.read('payload.tar.gz')
        receipt = json.loads(bundle.read('receipt.json'))
    trusted = {'repository': REPOSITORY, 'source_sha': sha, 'workflow_path': WORKFLOW_PATH,
               'run_id': run['id'], 'run_attempt': run.get('run_attempt', 1), 'artifact_name': artifact['name']}
    files = validate(archive, receipt, trusted)
    return archive, receipt, files, {'artifact_id': artifact['id'], 'run_id': run['id'], 'source_sha': sha}


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


def stage(root, archive, receipt, files, api_facts):
    key = receipt['source_sha'] + '-' + receipt['archive_sha256'][:16]
    for name in ('releases', 'receipts', 'assets'):
        (root / name).mkdir(parents=True, exist_ok=True)
    release = root / 'releases' / key
    archive_path = root / 'releases' / (key + '.tar.gz')
    with serialized(root):
        if release.exists():
            require(not release.is_symlink(), 'Release path is a symlink')
            require(archive_path.exists() and digest(archive_path.read_bytes()) == receipt['archive_sha256'], 'Retained release/archive conflict')
            for name, value in files.items():
                require((release / name).is_file() and digest((release / name).read_bytes()) == digest(value), 'Retained payload conflict')
            retained = root / 'receipts' / (key + '.json')
            if not retained.exists():
                atomic_json(retained, {**receipt, 'api_facts': api_facts, 'release': key})
            return key
        with tempfile.TemporaryDirectory(prefix='.incoming-', dir=root / 'releases') as temporary:
            staging = Path(temporary) / 'tree'
            staging.mkdir()
            for name, value in files.items():
                p = staging / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_bytes(value)
                p.chmod(0o444)
            for p in staging.rglob('*'):
                if p.is_dir():
                    p.chmod(0o755)
            if archive_path.exists():
                require(digest(archive_path.read_bytes()) == receipt['archive_sha256'], 'Retained archive conflict')
            else:
                archive_path.write_bytes(archive)
                archive_path.chmod(0o444)
            os.replace(staging, release)
            release.chmod(0o755)
        atomic_json(root / 'receipts' / (key + '.json'), {**receipt, 'api_facts': api_facts, 'release': key})
        sync_directory(root / 'releases')
    return key


def current_state(root):
    link = root / 'current'
    require(not link.exists() or link.is_symlink(), 'Current is not a symlink')
    current = os.readlink(link) if link.is_symlink() else None
    path = root / 'receipts/current.json'
    data = json.loads(path.read_text()) if path.exists() else None
    require((current is None and data is None) or (data is not None and current == 'releases/' + data['release']), 'Pointer/receipt need reconciliation')
    return current, data, digest(path.read_bytes()) if path.exists() else None


def reconcile(root):
    pending = root / 'receipts/pending.json'
    if not pending.exists():
        current_state(root)
        return
    data = json.loads(pending.read_text())
    link = root / 'current'
    current = os.readlink(link) if link.is_symlink() else None
    if current == 'releases/' + data['release']:
        atomic_json(root / 'receipts/current.json', data)
        data['outcome'] = 'reconciled-activated'
    elif current == data['old_pointer']:
        current_state(root)
        data['outcome'] = 'reconciled-before-switch'
    else:
        raise Rejected('Uncertain pointer; operator reconciliation required')
    atomic_json(root / 'receipts' / (data['transaction_id'] + '.json'), data)
    pending.unlink()
    sync_directory(pending.parent)


def _switch_fixtureable(root, key, authorized_sha, admit, expected_previous, rollback=False, interrupt=None):
    """Pure local transaction. No production CLI calls this until admission exists."""
    with serialized(root):
        reconcile(root)
        old, previous, previous_hash = current_state(root)
        require(previous_hash == expected_previous, 'Previous receipt changed; stale/concurrent request')
        require(admit() is True, 'Machine admission unavailable')
        record = json.loads((root / 'receipts' / (key + '.json')).read_text())
        require(authorized_sha() == record['source_sha'], 'Stale authorized source head')
        release = root / 'releases' / key
        require(release.is_dir() and not release.is_symlink(), 'Missing retained release')
        archive = (root / 'releases' / (key + '.tar.gz')).read_bytes()
        files = validate(archive, {k: v for k, v in record.items() if k not in ('api_facts', 'release')}, record)
        for name, value in files.items():
            p = release / name
            require(not p.is_symlink() and p.is_file() and digest(p.read_bytes()) == digest(value), 'Retained release corruption')
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
                p.write_bytes(value)
                p.chmod(0o444)
        transaction = {**record, 'transaction_id': str(uuid.uuid4()), 'release': key,
                       'previous_release': previous['release'] if previous else None,
                       'previous_receipt_sha256': previous_hash, 'old_pointer': old,
                       'outcome': 'rollback' if rollback else 'activated',
                       'at': datetime.now(timezone.utc).isoformat()}
        # Validation/copying can take time; recheck external authority at the
        # commit boundary rather than relying on the earlier preparation check.
        require(authorized_sha() == record['source_sha'], 'Stale authorized source head at switch')
        require(admit() is True, 'Machine admission unavailable at switch')
        require(current_state(root)[2] == expected_previous, 'Previous receipt changed at switch')
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
        atomic_json(root / 'receipts' / (transaction['transaction_id'] + '.json'), transaction)
        (root / 'receipts/pending.json').unlink()
        sync_directory(root / 'receipts')
    return transaction


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['prepare', 'pull', 'activate', 'rollback'])
    parser.add_argument('--state-dir', type=Path, default=Path('/var/lib/blog'))
    parser.add_argument('--workflow-id', type=int)
    parser.add_argument('--token-file', type=Path)
    options = parser.parse_args()
    # No flag, environment variable, token file or arbitrary hook bypasses this.
    if options.command != 'prepare':
        raise Rejected('machine-admission-unavailable: production activation/rollback/pull driver is not released')
    require(options.workflow_id and options.token_file, 'Verified workflow ID and read-only token file are required')
    api = GitHub(options.token_file.read_text().strip())
    archive, receipt, files, facts = acquire(api, options.workflow_id)
    key = stage(options.state_dir, archive, receipt, files, facts)
    print(json.dumps({'staged_release': key, 'source_sha': receipt['source_sha'], 'activated': False}))


if __name__ == '__main__':
    try:
        main()
    except Rejected as error:
        raise SystemExit('Blog release rejected: ' + str(error))
    except (HTTPError, OSError, ValueError, tarfile.TarError, zipfile.BadZipFile):
        # Do not print signed URLs, API bodies, tokens or downloaded content.
        raise SystemExit('Blog release rejected; activation remains unchanged. Check local validation/admission evidence.')
