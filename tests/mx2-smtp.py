"""One bounded SMTP transaction from the untrusted fixture VM."""

import json
import smtplib
import sys

request = json.loads(sys.argv[1])
marker = request.get("marker", "probe")
body = f"mx2 marker: {marker}\nContent survives forwarding: abc 123 !\n"
message = (
    f"From: <{request['sender']}>\r\n"
    f"To: <{request['recipient']}>\r\n"
    f"Message-ID: <{marker}@sender.test>\r\n"
    f"Subject: mx2 {marker}\r\n\r\n" + body.replace("\n", "\r\n")
)
with smtplib.SMTP(
    request.get("host", "192.168.1.20"),
    timeout=15,
    source_address=(request.get("source", "192.168.1.10"), 0),
) as smtp:
    code, reply = smtp.ehlo("sender.test")
    result = {"ehlo": code, "features": smtp.esmtp_features}
    options = [f"SIZE={request['size']}"] if "size" in request else []
    code, reply = smtp.mail(request["sender"], options=options)
    result.update(stage="mail", code=code, reply=reply.decode())
    if code == 250:
        code, reply = smtp.rcpt(request["recipient"])
        result.update(stage="rcpt", code=code, reply=reply.decode())
        if code == 250 and not request.get("probe", False):
            code, reply = smtp.data(message)
            result.update(stage="data", code=code, reply=reply.decode())
    print(json.dumps(result))
