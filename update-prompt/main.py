#!/usr/bin/env python3
"""Interactive version picker for Companion v3+.

Fetches the available builds from the Bitfocus API and lets the user choose one,
writing the selected tarball URL to /tmp/companion-version-selection for update.sh
to consume.

Stdlib only so it runs on any python3 shipped by Debian 11-14 and Ubuntu 20.04+.
urllib honours http_proxy/https_proxy automatically
"""

import json
import os
import platform
import select
import sys
import termios
import tty
import urllib.request

# Majors of Companion that this updater knows how to install.
# A future major must be added here ONLY once it is confirmed compatible - we do
# not auto-accept future majors, as the packaging format could change and silently
# break the install otherwise.
ALLOWED_MAJORS = {3, 4, 5}

SELECTION_FILE = "/tmp/companion-version-selection"
API_URL = "https://api.bitfocus.io/v1/product/companion/packages"


def get_current_version():
    """Best-effort read of the currently installed build."""
    try:
        with open("/opt/companion/BUILD") as f:
            return f.read().strip()
    except OSError:
        # Assume none installed
        return None


def get_target():
    """Mirror the JS target detection: `${platform}-${arch}-tgz`, with the
    linux-x64 special case collapsed to `linux-tgz`."""
    machine = platform.machine()
    arch = {"x86_64": "x64", "aarch64": "arm64"}.get(machine, machine)
    target = "linux-{}-tgz".format(arch)
    if target == "linux-x64-tgz":
        target = "linux-tgz"
    return target


def version_allowed(version):
    """Replacement for semver.satisfies against the allowed majors.

    Parses the leading MAJOR of a `MAJOR.MINOR.PATCH[-pre]` string and checks it
    against ALLOWED_MAJORS. Returns False for anything unparseable (matching the
    old try/catch behaviour)."""
    if version is None:
        return False
    # stable builds are tagged with a leading "v" (e.g. "v4.3.4"), beta builds are
    # not (e.g. "5.0.0+9502-main-..."); strip an optional leading v like semver did.
    text = str(version).lstrip("vV")
    try:
        major = int(text.split(".", 1)[0])
    except ValueError:
        return False
    return major in ALLOWED_MAJORS


def get_latest_builds(branch, target_count):
    """Fetch up to target_count builds for a branch, newest first."""
    target = get_target()
    url = "{}?branch={}&limit={}&target={}".format(
        API_URL, branch, target_count, target
    )

    with urllib.request.urlopen(url) as response:
        data = json.loads(response.read().decode("utf-8"))

    # assume the builds are sorted by date already
    result = []
    for pkg in data.get("packages", []):
        if pkg.get("target") == target and version_allowed(pkg.get("version")):
            result.append({"name": pkg["version"], "uri": pkg["uri"]})
    return result


def write_selection(uri):
    with open(SELECTION_FILE, "w") as f:
        f.write(uri)


def _read_key(fd):
    """Read a single keypress (or escape sequence) from a raw-mode terminal fd.

    Returns 'up'/'down'/'enter'/'cancel' for the keys we care about, or the raw
    character otherwise. Reads the fd directly (unbuffered) - going through the
    buffered sys.stdin would slurp the whole escape sequence at once and defeat the
    select() below. select() also lets a lone Esc resolve without blocking."""
    ch = os.read(fd, 1)
    if ch == b"\x03":  # Ctrl-C
        raise KeyboardInterrupt
    if ch in (b"\r", b"\n"):
        return "enter"
    if ch == b"k":
        return "up"
    if ch == b"j":
        return "down"
    if ch == b"q":
        return "cancel"
    if ch == b"\x1b":
        # might be an arrow-key escape sequence (Esc [ A/B, or Esc O A/B in
        # application-cursor mode); read the rest if it arrives promptly
        seq = b""
        while select.select([fd], [], [], 0.05)[0]:
            seq += os.read(fd, 1)
            if len(seq) >= 2:
                break
        if seq in (b"[A", b"OA"):
            return "up"
        if seq in (b"[B", b"OB"):
            return "down"
        return "cancel"  # bare Esc
    return ch.decode("utf-8", "ignore")


def select_menu(title, choices):
    """Inline arrow-key menu. Returns the chosen string, or None if cancelled.

    Renders the prompt and options on their own lines and redraws only those lines
    on navigation (no full-screen clear, so no flashing), then collapses them away
    on exit - mimicking the old inquirer behaviour. Falls back to a numbered prompt
    when stdin/stdout is not a real terminal (e.g. piped input)."""
    if not (sys.stdin.isatty() and sys.stdout.isatty()):
        return _select_menu_fallback(title, choices)

    n = len(choices)
    idx = 0

    def draw(first):
        if not first:
            sys.stdout.write("\x1b[{}A".format(n))  # cursor back up to first option
        for i, choice in enumerate(choices):
            if i == idx:
                line = "\x1b[36m> {}\x1b[0m".format(choice)  # highlighted (cyan)
            else:
                line = "  {}".format(choice)
            sys.stdout.write("\r\x1b[2K" + line + "\n")  # clear line then write
        sys.stdout.flush()

    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    sys.stdout.write(title + "\n")
    sys.stdout.write("\x1b[?25l")  # hide cursor
    draw(True)
    result = None
    try:
        tty.setraw(fd)
        while True:
            key = _read_key(fd)
            if key == "enter":
                result = choices[idx]
                break
            if key == "cancel":
                result = None
                break
            if key == "up":
                idx = (idx - 1) % n
            elif key == "down":
                idx = (idx + 1) % n
            else:
                continue
            draw(False)
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
        # collapse: move up over the options + title, back to column 0 (raw-mode
        # newlines don't carriage-return, so the cursor may be mid-line), then clear
        sys.stdout.write("\x1b[{}A\r\x1b[J".format(n + 1))
        sys.stdout.write("\x1b[?25h")  # show cursor
        sys.stdout.flush()
    return result


def _select_menu_fallback(title, choices):
    """Numbered-list prompt for non-tty stdin (no raw mode / escape codes)."""
    print(title)
    for i, choice in enumerate(choices):
        print("  {}) {}".format(i + 1, choice))
    try:
        raw = input("Enter a number: ").strip()
        return choices[int(raw) - 1]
    except (ValueError, IndexError, EOFError):
        return None


def confirm(message):
    """Simple [y/N] confirm using plain input (after curses has torn down)."""
    answer = input("{} [y/N]: ".format(message)).strip().lower()
    return answer in ("y", "yes")


def select_build_of_type(build_type, target_build=None):
    """Non-interactive: pick the requested (or newest) build of a branch."""
    candidates = get_latest_builds(build_type, 1)
    selected = None
    if target_build:
        selected = next((c for c in candidates if c["name"] == target_build), None)
    elif candidates:
        selected = candidates[0]

    if selected:
        if selected["name"] == get_current_version():
            print(
                "The latest build of {} ({}) is already installed".format(
                    build_type, selected["name"]
                )
            )
        else:
            print("Selected {}: {}".format(build_type, selected["name"]))
            write_selection(selected["uri"])
    else:
        print("No matching {} build was found!".format(build_type), file=sys.stderr)


def choose_of_type(build_type):
    """Interactive: list the latest builds of a branch and let the user pick."""
    candidates = get_latest_builds(build_type, 10)

    if not candidates:
        print("No {} build was found!".format(build_type), file=sys.stderr)
        return

    choice = select_menu(
        "Which version do you want?", [c["name"] for c in candidates] + ["cancel"]
    )

    if not choice or choice == "cancel":
        print("No version was selected!", file=sys.stderr)
        return

    if choice == get_current_version():
        if not confirm(
            'Build "{}" is already installed. Do you wish to reinstall it?'.format(
                choice
            )
        ):
            return

    build = next((c for c in candidates if c["name"] == choice), None)
    if build:
        print("Selected {}: {}".format(build_type, build["name"]))
        write_selection(build["uri"])
    else:
        print("Invalid selection!", file=sys.stderr)


def run_prompt():
    print(
        "Warning: Downgrading to an older version can cause issues with the "
        "database not being compatible"
    )
    print('You are currently on "{}"'.format(get_current_version() or "Unknown"))

    choice = select_menu(
        "What version do you want?",
        [
            "latest stable",
            "latest beta",
            "specific stable",
            "specific beta",
            "custom-url",
            "cancel",
        ],
    )

    if choice == "custom-url":
        print(
            "Warning: This must be an linux build of Companion for the correct "
            "architecture, or companion will not be able to launch afterwards"
        )
        url = input("What build url? ").strip()
        if not url:
            print("No version was selected!", file=sys.stderr)
            return
        if confirm(
            'Are you sure you to download the build "{}"?\nMake sure you trust the '
            "source.\nIf you don't know what you are doing you could break your "
            "CompanionPi installation".format(url)
        ):
            write_selection(url)
        else:
            run_prompt()
    elif not choice or choice == "cancel":
        print("No version was selected!", file=sys.stderr)
    elif choice == "latest beta":
        select_build_of_type("beta")
    elif choice == "latest stable":
        select_build_of_type("stable")
    elif choice == "specific beta":
        choose_of_type("beta")
    elif choice == "specific stable":
        choose_of_type("stable")


def main():
    if len(sys.argv) > 1 and sys.argv[1]:
        target_build = sys.argv[2] if len(sys.argv) > 2 else None
        select_build_of_type(sys.argv[1], target_build)
    else:
        run_prompt()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        # Treat Ctrl-C like the "cancel" option: no selection is written, so
        # update.sh skips the update. Exit 0 so its `set -e` doesn't abort the
        # rest of the tooling update.
        print("\nCancelled", file=sys.stderr)
        sys.exit(0)
