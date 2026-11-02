import email
import json
import re
import shlex
import time


def smtp(recipient, marker, *, source="192.168.1.10", host="192.168.1.20", **options):
    request = {
        "recipient": recipient,
        "sender": marker + "@sender.test",
        "marker": marker,
        "source": source,
        "host": host,
        **options,
    }
    return json.loads(
        sender.succeed(
            "python3 /etc/mx2-smtp.py " + shlex.quote(json.dumps(request)), timeout=25
        )
    )


def eventually(function, timeout=90):
    deadline = time.monotonic() + timeout
    while True:
        result = function()
        if result:
            return result
        assert time.monotonic() < deadline, "condition did not become true"
        time.sleep(2)


def submit(recipient, marker, **options):
    def attempt():
        response = smtp(recipient, marker, **options)
        if response["stage"] == "rcpt" and 400 <= response["code"] < 500:
            assert "Greylisted" in response["reply"], response
            return None
        assert response["stage"] == "data" and response["code"] == 250, response
        match = re.search(r"queued as ([A-Z0-9]+)", response["reply"])
        assert match is not None, response
        return match.group(1)

    return eventually(attempt, timeout=45)


def records(machine):
    command = (
        "import json,pathlib; print(json.dumps([json.loads(p.read_text()) "
        "for p in pathlib.Path('/var/lib/mail-fixture').glob('*.json')]))"
    )
    return json.loads(machine.succeed("python3 -c " + shlex.quote(command)))


def delivered(machine, marker):
    return eventually(
        lambda: next((r for r in records(machine) if marker in r["message"]), None),
        timeout=120,
    )


def check_message(record, recipient, marker):
    assert record["sender"] == marker + "@sender.test", record
    assert record["recipient"] == recipient, record
    message = email.message_from_string(record["message"])
    assert message["Message-ID"] == f"<{marker}@sender.test>", record
    assert message["Subject"] == "mx2 " + marker, record
    payload = message.get_payload()
    assert isinstance(payload, str), record
    assert payload.replace("\r\n", "\n") == (
        f"mx2 marker: {marker}\nContent survives forwarding: abc 123 !\n"
    ), record
    return message


def queue():
    return [json.loads(line) for line in mx.succeed("postqueue -j").splitlines()]


def queued(queue_id, marker):
    items = queue()
    item = next((item for item in items if item["queue_id"] == queue_id), None)
    assert item is not None, items
    assert item["sender"] == marker + "@sender.test", item
    assert marker in mx.succeed("postcat -q " + shlex.quote(queue_id))
    return item


def recipient_map(temporary=True):
    text = "permanent@vpsfree.cz 550 5.1.1 fixture permanent rejection\n"
    if temporary:
        text += "temporary@vpsfree.cz 450 4.2.0 fixture temporary rejection\n"
    primary.succeed(
        "printf %s " + shlex.quote(text) + " > /var/lib/postfix/fixture-recipients && "
        "postmap /var/lib/postfix/fixture-recipients && postfix reload"
    )


# The native driver otherwise exits QEMU at guest reboot (-no-reboot).
mx.start(allow_reboot=True)
start_all()
for machine in (sender, mx, primary):
    machine.wait_for_unit("multi-user.target", timeout=90)
    machine.wait_for_unit("postfix.service", timeout=90)
    machine.succeed('test -z "$(ip -4 route show default)"')
    machine.succeed('test -z "$(ip -6 route show default)"')
    assert machine.succeed("grep '^nameserver ' /etc/resolv.conf").strip() == (
        "nameserver 192.168.1.30"
    )
primary.wait_for_unit("dnsmasq.service", timeout=30)
mx.wait_for_unit("postgrey.service", timeout=30)
recipient_map()

with subtest("isolated DNS, effective policy and enabled SMTP firewall"):
    for machine in (sender, mx):
        assert (
            machine.succeed("dig +short prasiatko-mail.vpsfree.cz A").strip()
            == "192.168.1.30"
        )
        assert (
            machine.succeed("dig +short prasiatko-mail.vpsfree.cz AAAA").strip()
            == "fd42:6d78:32::30"
        )
        assert (
            machine.succeed("dig +short +time=2 +tries=1 unavailable.invalid").strip()
            == ""
        )
        assert (
            machine.succeed(
                "dig +short +time=2 +tries=1 10.1.168.192.zen.spamhaus.org"
            ).strip()
            == ""
        )
    assert (
        sender.succeed("dig +short 11.1.168.192.zen.spamhaus.org").strip()
        == "127.0.0.2"
    )
    mx.succeed("systemctl is-active firewall; iptables-save | grep -- '--dport 25'")
    mx.succeed("ip6tables-save | grep -- '--dport 25'")
    assert set(mx.succeed("postconf -h relay_domains").replace(",", " ").split()) == {
        "vpsfree.cz",
        "lists.vpsfree.cz",
        "vpsfree.org",
    }
    assert "relay_domains" not in mx.succeed(
        "postconf -h parent_domain_matches_subdomains"
    )
    assert mx.succeed("postconf -h mynetworks_style").strip() == "host"
    trusted = mx.succeed("postconf -h mynetworks")
    assert "192.168.1.10" not in trusted and "fd42:6d78:32::10" not in trusted, trusted
    assert mx.succeed("postconf -h queue_directory").strip() == "/var/lib/postfix/queue"
    assert mx.succeed("postconf -h data_directory").strip() == "/var/lib/postfix/data"
    mx.succeed("test -S /run/postgrey.sock; test -d /var/postgrey")
    assert mx.succeed("postconf -h smtpd_milters").strip() == "inet:localhost:11332"
    assert mx.succeed("postconf -h milter_default_action").strip() == "accept"
    mx.fail("ss -ltn | grep ':11332 '")
    features = smtp("probe@vpsfree.cz", "features", probe=True)["features"]
    assert features["size"] == "104857600" and "starttls" not in features, features
    oversized = smtp("probe@vpsfree.cz", "oversize", size=104857601)
    assert oversized["stage"] == "mail" and oversized["code"] == 552, oversized

with subtest("relay denial is independent of greylisting and never queues DATA"):
    for domain in ("unrelated.test", "arbitrary.vpsfree.cz"):
        assert (
            mx.succeed("dig +short +time=2 +tries=1 " + domain).strip()
            == "192.168.1.30"
        )
    for source, host in (
        ("192.168.1.10", "192.168.1.20"),
        ("fd42:6d78:32::10", "fd42:6d78:32::20"),
    ):
        for recipient in ("user@unrelated.test", "user@arbitrary.vpsfree.cz"):
            response = smtp(recipient, "deny", source=source, host=host, probe=True)
            assert response["stage"] == "rcpt" and 500 <= response["code"] < 600, (
                response
            )
            assert queue() == []
    for recipient in ("bad@@vpsfree.cz", "user@unavailable.invalid"):
        response = smtp(recipient, "deny", probe=True)
        assert response["stage"] == "rcpt" and 500 <= response["code"] < 600, response
    assert queue() == []

with subtest("fresh Postgrey tuple, retry and policy-state restart persistence"):
    response = smtp("grey@vpsfree.cz", "grey", probe=True)
    assert response["stage"] == "rcpt" and response["code"] == 450, response
    assert "Greylisted" in response["reply"], response
    time.sleep(3)
    assert smtp("grey@vpsfree.cz", "grey", probe=True)["code"] == 250
    mx.succeed("systemctl restart postgrey")
    mx.wait_for_unit("postgrey.service", timeout=30)
    mx.wait_until_succeeds("test -S /run/postgrey.sock", timeout=30)
    assert smtp("grey@vpsfree.cz", "grey", probe=True)["code"] == 250

with subtest("original DNSBL rejects a listed external source"):
    sender.succeed("ip -4 -o address show dev eth1 | grep -F 'inet 192.168.1.11/24 '")

    def listed():
        response = smtp(
            "listed@vpsfree.cz", "listed", source="192.168.1.11", probe=True
        )
        if response["code"] == 450 and "Greylisted" in response["reply"]:
            return None
        assert response["stage"] == "rcpt" and 500 <= response["code"] < 600, response
        assert "spamhaus" in response["reply"].lower(), response
        return True

    eventually(listed, timeout=45)
    assert queue() == []

with subtest(
    "exact-domain delivery, envelopes/content, IPv4/IPv6 and missing-milter fail-open"
):
    for index, domain in enumerate(("vpsfree.cz", "lists.vpsfree.cz", "vpsfree.org")):
        marker = "delivery-" + str(index)
        recipient = "recipient@" + domain
        submit(recipient, marker)
        message = check_message(delivered(primary, marker), recipient, marker)
        assert any(
            "by primary.test" in h and "ESMTPS" in h
            for h in message.get_all("Received", [])
        )
    submit(
        "ipv6@vpsfree.cz", "ipv6", source="fd42:6d78:32::10", host="fd42:6d78:32::20"
    )
    check_message(delivered(primary, "ipv6"), "ipv6@vpsfree.cz", "ipv6")
    eventually(lambda: not queue())

with subtest("unavailable policy service temporarily rejects before DATA"):
    mx.succeed("systemctl stop postgrey")
    response = smtp("policy@vpsfree.cz", "policy", probe=True)
    assert response["stage"] == "rcpt" and 400 <= response["code"] < 500, response
    assert queue() == []
    mx.succeed("systemctl start postgrey")
    mx.wait_until_succeeds("test -S /run/postgrey.sock", timeout=30)

with subtest("accepted outage queue survives Postfix restart and reboot, then drains"):
    primary.succeed("systemctl stop postfix && systemctl is-active dnsmasq")
    queue_id = submit("outage@vpsfree.cz", "outage")
    item = queued(queue_id, "outage")
    assert item["recipients"][0]["address"] == "outage@vpsfree.cz", item
    mx.succeed("systemctl restart postfix")
    mx.wait_for_unit("postfix.service", timeout=30)
    queued(queue_id, "outage")
    mx.reboot()
    mx.wait_for_unit("postfix.service", timeout=90)
    mx.wait_for_unit("postgrey.service", timeout=30)
    queued(queue_id, "outage")
    assert smtp("grey@vpsfree.cz", "grey", probe=True)["code"] == 250
    primary.succeed("systemctl start postfix")
    primary.wait_for_unit("postfix.service", timeout=30)
    mx.succeed("postqueue -f")
    check_message(delivered(primary, "outage"), "outage@vpsfree.cz", "outage")
    eventually(lambda: not queue(), timeout=120)

with subtest("primary 4xx defers accepted message until recovery"):
    queue_id = submit("temporary@vpsfree.cz", "temporary")
    eventually(
        lambda: any(
            i["queue_id"] == queue_id and i["queue_name"] == "deferred" for i in queue()
        )
    )
    item = queued(queue_id, "temporary")
    assert any(
        recipient["address"] == "temporary@vpsfree.cz"
        and "450 4.2.0 " in recipient.get("delay_reason", "")
        and "fixture temporary rejection" in recipient.get("delay_reason", "")
        for recipient in item["recipients"]
    ), item
    recipient_map(temporary=False)
    mx.succeed("postqueue -f")
    check_message(delivered(primary, "temporary"), "temporary@vpsfree.cz", "temporary")
    eventually(lambda: not queue(), timeout=120)

with subtest("primary permanent rejection returns a DSN to the controlled sender"):
    submit("permanent@vpsfree.cz", "permanent")
    bounce = delivered(sender, "permanent")
    assert bounce["recipient"] == "permanent@sender.test", bounce
    message = bounce["message"].lower()
    assert "delivery-status" in message and "status: 5.1.1" in message, bounce
    assert "final-recipient: rfc822; permanent@vpsfree.cz" in message, bounce
    assert "fixture permanent rejection" in message, bounce
    eventually(lambda: not queue(), timeout=120)

with subtest("opportunistic outbound TLS permits a primary without STARTTLS"):
    primary.succeed(
        "postconf -e 'smtpd_tls_security_level = none' && systemctl restart postfix"
    )
    primary.wait_for_unit("postfix.service", timeout=30)
    submit("plaintext@vpsfree.cz", "plaintext")
    message = check_message(
        delivered(primary, "plaintext"), "plaintext@vpsfree.cz", "plaintext"
    )
    assert any(
        "by primary.test" in h and "with ESMTP " in h
        for h in message.get_all("Received", [])
    )
    assert not any(
        "by primary.test" in h and "ESMTPS" in h
        for h in message.get_all("Received", [])
    )
    assert mx.succeed("postconf -h smtp_tls_security_level").strip() == "may"
    eventually(lambda: not queue(), timeout=120)
