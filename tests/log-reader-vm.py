import shlex

start_all()
logger.wait_for_unit("sshd.service")
logger.wait_for_unit("syslog.service")
logger.succeed("systemctl stop logrotate.timer")
logger.succeed("cp /etc/test-client-key /root/test-key; chmod 600 /root/test-key")
ssh = "ssh -i /root/test-key -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null log-reader@localhost"


def remote(command):
    return ssh + " " + shlex.quote(command)


def ingest(host, marker):
    # Production senders use LocalHostName plus SyslogProtocol23Format. RFC3164
    # does not preserve this slash-containing hostname in rsyslog's parser.
    payload = f"<13>1 2026-10-21T12:00:00Z {host} fixture - - - {marker}\n"
    logger.succeed(
        "python3 -c " + shlex.quote(
            "import socket; s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM); "
            f"s.sendto({payload.encode()!r}, ('127.0.0.1', 11515))"
        )
    )


def wait_for_ingested(current, marker):
    try:
        logger.wait_until_succeeds(remote(f"grep {marker} {current}"), timeout=30)
        logger.wait_until_succeeds(f"grep {marker} /var/lib/test-exporter/captured", timeout=30)
    except Exception:
        for command in [
            "journalctl -b -u syslog.service -u test-exporter.service --no-pager -n 80",
            "ss -H -lun; find /var/log/remote -maxdepth 8 -printf '%m %u:%g %p\\n'",
        ]:
            print(logger.execute(command)[1])
        raise


with subtest("reviewed historical reconciliation and refusal boundaries"):
    logger.succeed("systemctl stop syslog.socket syslog.service")
    logger.fail("systemctl is-active --quiet syslog.socket")
    logger.fail("systemctl is-active --quiet syslog.service")
    logger.succeed("install -d -m 700 /var/log/remote/legacy")
    logger.succeed("printf archive > /var/log/remote/legacy/log-20260101; chmod 600 /var/log/remote/legacy/log-20260101")
    logger.succeed("printf archive > /var/log/messages-20260101; chmod 600 /var/log/messages-20260101")
    logger.succeed("printf unrelated > /var/log/unrelated; chmod 600 /var/log/unrelated")
    logger.fail(remote("cat /var/log/remote/legacy/log-20260101"))
    logger.succeed("ln -s /etc/shadow /var/log/remote/escape")
    logger.fail("log-reader-reconcile --inventory /root/refused.json")
    logger.succeed("test ! -e /root/refused.json; rm /var/log/remote/escape")
    logger.succeed("mkfifo /var/log/remote/special")
    logger.fail("log-reader-reconcile --inventory /root/refused.json")
    logger.succeed("rm /var/log/remote/special")
    logger.succeed("ln /var/log/unrelated /var/log/remote/hardlink")
    logger.fail("log-reader-reconcile --inventory /root/refused.json")
    logger.succeed("rm /var/log/remote/hardlink")
    logger.succeed("setfacl -m u:log-reader:r /var/log/remote/legacy/log-20260101")
    logger.fail("log-reader-reconcile --inventory /root/refused.json")
    logger.succeed("setfacl -b /var/log/remote/legacy/log-20260101")
    logger.fail("log-reader-reconcile --max-entries 1 --inventory /root/refused.json")
    logger.succeed("mount -t tmpfs tmpfs /var/log/remote/legacy")
    logger.fail("log-reader-reconcile --inventory /root/refused.json")
    logger.succeed("umount /var/log/remote/legacy")
    logger.succeed("log-reader-reconcile --inventory /root/before.json")
    logger.succeed("log-reader-reconcile --apply /root/before.json")
    logger.succeed("log-reader-reconcile --apply /root/before.json")
    logger.succeed(remote("grep archive /var/log/remote/legacy/log-20260101"))
    logger.succeed(remote("tail -n 1 /var/log/messages-20260101"))
    logger.succeed("test $(stat -c %a:%U:%G /var/log/unrelated) = 600:root:root")
    logger.succeed("systemctl start syslog.socket syslog.service")
    logger.wait_for_unit("test-exporter.service")
    logger.wait_until_succeeds("ss -H -lun 'sport = :11515' | grep -q .", timeout=10)

with subtest("new host creation, ingestion and exporter pipe"):
    logger.succeed("test ! -e /var/log/remote/cz.vpsfree")
    ingest("cz.vpsfree/nodes/prg/node-fixture", "before-rotation")
    current = "/var/log/remote/cz.vpsfree/nodes/prg/node-fixture/log"
    wait_for_ingested(current, "before-rotation")
    logger.succeed(f"test $(stat -c %a:%U:%G {current}) = 640:root:log-readers")
    directory = "/var/log/remote"
    for component in ["cz.vpsfree", "nodes", "prg", "node-fixture"]:
        directory += "/" + component
        logger.succeed(f"test $(stat -c %a:%U:%G {directory}) = 750:root:log-readers")
    logger.succeed("test $(stat -c %a:%U:%G /var/log/rsyslog.pipe) = 640:root:syslog-exporter")
    logger.succeed("logger local-reader-marker")
    logger.wait_until_succeeds(remote("grep local-reader-marker /var/log/messages"), timeout=30)
    logger.succeed("test $(stat -c %a:%U:%G /var/log/messages) = 640:root:log-readers")

with subtest("protected logs, directories and privileged actions"):
    for command in [
        f"echo corrupt >> {current}", f": > {current}", f"rm {current}",
        f"mv {current} {current}.moved", f"touch {current}.new",
        "echo corrupt >> /var/log/messages", "rm /var/log/messages-20260101",
        "cat /etc/shadow", "touch /etc/reader-test", "sudo -n true",
        "systemctl restart syslog.service",
    ]:
        logger.fail(remote(command))
    logger.succeed(remote("touch ~/allowed-home-write /tmp/allowed-temp-write"))
    groups = logger.succeed("id -nG log-reader").split()
    assert groups == ["log-readers"], groups
    logger.fail(remote("cat /var/log/rsyslog.pipe"))

with subtest("SSH policy and root-managed keys"):
    policy = logger.succeed("sshd -T -C user=log-reader,host=arbitrary,addr=198.51.100.9").lower()
    for directive in [
        "authenticationmethods publickey", "passwordauthentication no",
        "kbdinteractiveauthentication no", "authorizedkeysfile /etc/ssh/authorized_keys.d/%u",
        "disableforwarding yes", "allowtcpforwarding no", "allowstreamlocalforwarding no",
        "allowagentforwarding no", "x11forwarding no", "permittty no",
        "permittunnel no", "permituserrc no", "authorizedkeyscommand none",
    ]:
        assert directive in policy, directive
    logger.fail(remote("echo unrestricted >> /etc/ssh/authorized_keys.d/log-reader"))
    logger.succeed("ssh-keygen -q -t ed25519 -N '' -f /root/unrestricted")
    logger.succeed("install -d -o log-reader -g log-readers /home/log-reader/.ssh; cp /root/unrestricted.pub /home/log-reader/.ssh/authorized_keys; chown log-reader:log-readers /home/log-reader/.ssh/authorized_keys")
    logger.fail("ssh -i /root/unrestricted -o BatchMode=yes -o StrictHostKeyChecking=no log-reader@localhost true")
    logger.succeed(remote("printf 'touch /tmp/user-rc-ran\\n' > ~/.ssh/rc"))
    logger.succeed(remote("true"))
    logger.succeed("test ! -e /tmp/user-rc-ran")
    logger.fail(ssh.replace(" log-reader@", " -tt log-reader@") + " test -t 0")
    logger.fail(ssh.replace(" log-reader@", " -o ExitOnForwardFailure=yes -R 12345:localhost:22 log-reader@") + " true")

with subtest("rotation keeps current and archived logs readable"):
    logger.succeed("systemctl start logrotate.service")
    logger.succeed(remote(f"grep before-rotation {current}-*"))
    ingest("cz.vpsfree/nodes/prg/node-fixture", "after-rotation")
    wait_for_ingested(current, "after-rotation")
    logger.succeed(f"test $(stat -c %a:%U:%G {current}) = 640:root:log-readers")
    logger.succeed("test $(stat -c %a:%U:%G /var/log/messages) = 640:root:log-readers")
    logger.succeed(remote("grep local-reader-marker /var/log/messages-*"))
