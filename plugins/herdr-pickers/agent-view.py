#!/usr/bin/env python3
"""Sort Herdr's agent list by what needs attention first.

Herdr's built-in "priority" sort puts working agents above finished ones that
have been seen ("idle"). This sets a plugin-owned agent view instead: blocked
agents first, then finished ones ("done", then "idle"), then working ones, with
the newest state change first in each group. The view orders the sidebar and
prefix+alt+j/k; picker.sh sorts prefix+a the same way.

Status names sort alphabetically into that order (blocked, done, idle, unknown,
working), so one ascending status key is enough. Herdr keeps the view in
memory only, so the plugin sets it again on every server start. Disabling the
plugin removes it.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import socket
import sys

PLUGIN_ID = "teddyhwang.pickers"
VIEW = {
    "source": f"plugin:{PLUGIN_ID}",
    "label": "priority",
    "sort": [
        {"field": "status", "order": "asc"},
        {"field": "state_change_seq", "order": "desc"},
    ],
}


def socket_path() -> str:
    configured = os.environ.get("HERDR_SOCKET_PATH")
    if configured:
        return configured

    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    session = os.environ.get("HERDR_SESSION")
    if session and session != "default":
        return str(config_home / "herdr" / "sessions" / session / "herdr.sock")
    return str(config_home / "herdr" / "herdr.sock")


def main() -> int:
    request_id = f"{PLUGIN_ID}:agent-view:{os.getpid()}"
    request = {"id": request_id, "method": "agent.view.set", "params": VIEW}
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(5)
            client.connect(socket_path())
            client.sendall(json.dumps(request, separators=(",", ":")).encode() + b"\n")
            response_line = client.makefile("rb").readline()
        if not response_line:
            raise RuntimeError("Herdr closed the socket without a response")
        response = json.loads(response_line)
        if response.get("id") != request_id:
            raise RuntimeError("Herdr returned a response with the wrong request ID")
        if "error" in response:
            error = response["error"]
            raise RuntimeError(error.get("message") or error.get("code") or "agent view failed")
    except (OSError, ValueError, RuntimeError) as error:
        print(f"agent-view: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
