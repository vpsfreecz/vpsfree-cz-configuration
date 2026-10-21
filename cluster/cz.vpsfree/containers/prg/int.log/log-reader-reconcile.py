"""Explicit, metadata-only reconciliation of the logger's historical files."""

import argparse
import grp
import json
import os
import re
import stat
import sys


DIRECTORY_FLAGS = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC
FILE_FLAGS = os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC
MESSAGES = re.compile(r"messages(?:-\d{8}|\.\d+)?(?:\.gz)?\Z")
ACL_NAMES = {"system.posix_acl_access", "system.posix_acl_default"}


class UnsafeMetadata(Exception):
    pass


def metadata(fd, path, device, reader_gid):
    info = os.fstat(fd)
    directory = stat.S_ISDIR(info.st_mode)
    if not directory and not stat.S_ISREG(info.st_mode):
        raise UnsafeMetadata(f"special file: {path}")
    if info.st_dev != device:
        raise UnsafeMetadata(f"foreign filesystem: {path}")
    if info.st_uid != 0 or info.st_gid not in (0, reader_gid):
        raise UnsafeMetadata(f"unexpected owner/group: {path}")
    if info.st_mode & 0o7022:
        raise UnsafeMetadata(f"special bits or group/other writes: {path}")
    if not directory and info.st_nlink != 1:
        raise UnsafeMetadata(f"hard-linked file: {path}")
    if ACL_NAMES.intersection(os.listxattr(fd)):
        raise UnsafeMetadata(f"extended/default ACL: {path}")
    return {
        "path": path,
        "device": info.st_dev,
        "inode": info.st_ino,
        "uid": info.st_uid,
        "gid": info.st_gid,
        "mode": stat.S_IMODE(info.st_mode),
        "kind": "directory" if directory else "file",
    }


def open_log_root(reader_gid):
    fd = os.open("/", DIRECTORY_FLAGS)
    try:
        for part in ("var", "log"):
            next_fd = os.open(part, DIRECTORY_FLAGS, dir_fd=fd)
            os.close(fd)
            fd = next_fd
            info = os.fstat(fd)
            if info.st_uid != 0 or info.st_mode & 0o022:
                raise UnsafeMetadata("/var/log parent must be root-owned and unwritable")
            if not (info.st_mode & 0o001 or (info.st_gid == reader_gid and info.st_mode & 0o010)):
                raise UnsafeMetadata("/var/log parents need existing log-reader traversal")
        return fd
    except BaseException:
        os.close(fd)
        raise


def reject_mounts():
    # st_dev alone cannot detect a bind mount of the same filesystem.
    with open("/proc/self/mountinfo", encoding="utf-8") as stream:
        for line in stream:
            mount = re.sub(
                r"\\([0-7]{3})", lambda match: chr(int(match[1], 8)), line.split()[4]
            )
            if mount == "/var/log/remote" or mount.startswith("/var/log/remote/"):
                raise UnsafeMetadata(f"mount inside remote tree: {mount}")
            if mount.startswith("/var/log/") and MESSAGES.fullmatch(mount[9:]):
                raise UnsafeMetadata(f"mount over messages: {mount}")


def inventory(root_fd, reader_gid, max_entries, max_depth):
    device = os.fstat(root_fd).st_dev
    parent = os.fstat(root_fd)
    if not (parent.st_mode & 0o001 or (parent.st_gid == reader_gid and parent.st_mode & 0o010)):
        raise UnsafeMetadata("/var/log needs existing log-reader traversal; inspect separately")
    rows = []

    def visit(parent_fd, name, path, depth):
        if depth > max_depth or len(rows) >= max_entries:
            raise UnsafeMetadata("inventory exceeds explicit entry/depth bound")
        before = os.stat(name, dir_fd=parent_fd, follow_symlinks=False)
        directory = stat.S_ISDIR(before.st_mode)
        if not directory and not stat.S_ISREG(before.st_mode):
            raise UnsafeMetadata(f"symlink or special file: {path}")
        fd = os.open(name, DIRECTORY_FLAGS if directory else FILE_FLAGS, dir_fd=parent_fd)
        try:
            row = metadata(fd, path, device, reader_gid)
            if (row["device"], row["inode"]) != (before.st_dev, before.st_ino):
                raise UnsafeMetadata(f"changed during inventory: {path}")
            rows.append(row)
            if directory:
                for child in sorted(os.listdir(fd)):
                    visit(fd, child, f"{path}/{child}", depth + 1)
        finally:
            os.close(fd)

    for name in sorted(os.listdir(root_fd)):
        if name == "remote" or MESSAGES.fullmatch(name):
            visit(root_fd, name, name, 0)
    return rows


def open_entry(root_fd, row):
    fd = os.dup(root_fd)
    try:
        parts = row["path"].split("/")
        for index, part in enumerate(parts):
            flags = DIRECTORY_FLAGS if index < len(parts) - 1 or row["kind"] == "directory" else FILE_FLAGS
            next_fd = os.open(part, flags, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        return fd
    except BaseException:
        os.close(fd)
        raise


def reconcile(root_fd, rows, reader_gid):
    # Validate the entire tree before the first write. The operator must quiesce
    # rotation/ingestion too: unrelated root processes can always change metadata.
    for row in rows:
        fd = open_entry(root_fd, row)
        try:
            if metadata(fd, row["path"], row["device"], reader_gid) != row:
                raise UnsafeMetadata(f"changed before apply: {row['path']}")
        finally:
            os.close(fd)
    for row in rows:
        fd = open_entry(root_fd, row)
        try:
            if metadata(fd, row["path"], row["device"], reader_gid) != row:
                raise UnsafeMetadata(f"changed during apply: {row['path']}; inspect partial changes")
            if row["gid"] != reader_gid:
                os.fchown(fd, 0, reader_gid)
            mode = 0o750 if row["kind"] == "directory" else 0o640
            if row["mode"] != mode:
                os.fchmod(fd, mode)
        finally:
            os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--inventory", metavar="NEW_JSON_FILE")
    action.add_argument("--apply", metavar="REVIEWED_JSON_FILE")
    parser.add_argument("--max-entries", type=int, default=100000)
    parser.add_argument("--max-depth", type=int, default=32)
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error("requires root")
    if args.max_entries < 1 or args.max_depth < 0:
        parser.error("invalid inventory bound")
    reader_gid = grp.getgrnam("log-readers").gr_gid
    reject_mounts()
    root_fd = open_log_root(reader_gid)
    try:
        rows = inventory(root_fd, reader_gid, args.max_entries, args.max_depth)
        snapshot = {"version": 1, "root": "/var/log", "reader_gid": reader_gid, "entries": rows}
        if args.inventory:
            # Never overwrite the recovery inventory or follow an output symlink.
            fd = os.open(args.inventory, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                json.dump(snapshot, stream, indent=2)
                stream.write("\n")
            print(f"inventoried {len(rows)} entries; no log metadata changed")
        else:
            fd = os.open(args.apply, FILE_FLAGS)
            with os.fdopen(fd, encoding="utf-8") as stream:
                info = os.fstat(stream.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_mode & 0o077:
                    raise UnsafeMetadata("reviewed inventory must be a private root-owned regular file")
                reviewed = json.load(stream)
            # The same reviewed inventory may be applied again: only our exact
            # target metadata may differ; identities and the scope must match.
            target = json.loads(json.dumps(reviewed))
            for row in target.get("entries", []):
                row["gid"] = reader_gid
                row["mode"] = 0o750 if row["kind"] == "directory" else 0o640
            if reviewed != snapshot and target != snapshot:
                raise UnsafeMetadata("inventory changed; take and review a fresh inventory")
            reconcile(root_fd, rows, reader_gid)
            print(f"reconciled {len(rows)} entries; retain the original recovery inventory")
    finally:
        os.close(root_fd)


if __name__ == "__main__":
    try:
        main()
    except (OSError, KeyError, ValueError, UnsafeMetadata) as error:
        sys.exit(f"log-reader-reconcile: {error}")
