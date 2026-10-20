"""Prepare an Amethyst preference profile without snapshot machine state."""

import plistlib
import sys


def machine_state(key):
    return key == "EncodedWindowManager" or key.startswith(("NS", "SU"))


def prepare(snapshot, current):
    # Replace the entire modern shortcut namespace, including stock-only binds.
    result = {key: value for key, value in current.items()
              if not key.startswith("KeyboardShortcuts_")}
    result.update({key: value for key, value in snapshot.items()
                   if not machine_state(key)})
    return result


if __name__ == "__main__":
    snapshot_path, output_path, current_path = sys.argv[1:]
    with open(snapshot_path, "rb") as source:
        snapshot = plistlib.load(source)
    current = {}
    if current_path:
        with open(current_path, "rb") as source:
            current = plistlib.load(source)
    with open(output_path, "wb") as output:
        plistlib.dump(prepare(snapshot, current), output)
