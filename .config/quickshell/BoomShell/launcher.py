#!/usr/bin/env python3
"""Application launcher backend for the BoomShell launcher panel.

Scans XDG .desktop entries, launches them and remembers hidden apps so the
launcher can skip them.
"""

import argparse
import configparser
import json
import os
import re
import shlex
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")
STATE_DIR = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local", "state"),
    "boom-launcher",
)
HIDDEN_FILE = os.path.join(STATE_DIR, "hidden.json")


def applications_dirs():
    data_home = os.environ.get("XDG_DATA_HOME") or os.path.join(HOME, ".local", "share")
    data_dirs = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"

    dirs = [os.path.join(data_home, "applications")]
    for base in data_dirs.split(":"):
        if base:
            dirs.append(os.path.join(base, "applications"))

    unique = []
    for directory in dirs:
        if directory not in unique and os.path.isdir(directory):
            unique.append(directory)
    return unique


def locale_suffixes():
    locale = (os.environ.get("LC_MESSAGES") or os.environ.get("LANG") or "").split(".")[0]
    suffixes = []
    if locale:
        suffixes.append(locale)
        language = locale.split("_")[0]
        if language != locale:
            suffixes.append(language)
    return suffixes


def read_hidden():
    try:
        with open(HIDDEN_FILE, encoding="utf-8") as handle:
            data = json.load(handle)
        return {str(path) for path in data}
    except (OSError, ValueError):
        return set()


def write_hidden(paths):
    os.makedirs(STATE_DIR, exist_ok=True)
    temporary = HIDDEN_FILE + ".tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(sorted(paths), handle, ensure_ascii=False, indent=2)
    os.replace(temporary, HIDDEN_FILE)


def parse_entry(path):
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    try:
        parser.read(path, encoding="utf-8")
    except (configparser.Error, OSError, UnicodeDecodeError):
        return None

    if not parser.has_section("Desktop Entry"):
        return None

    entry = parser["Desktop Entry"]
    if entry.get("Type", "Application").strip() != "Application":
        return None
    if entry.get("Hidden", "").strip().lower() == "true":
        return None
    if entry.get("NoDisplay", "").strip().lower() == "true":
        return None

    command = entry.get("Exec", "").strip()
    if not command:
        return None

    try_exec = entry.get("TryExec", "").strip()
    if try_exec and shutil.which(try_exec) is None and not os.access(try_exec, os.X_OK):
        return None

    name = None
    comment = None
    for suffix in locale_suffixes():
        if name is None:
            name = entry.get("Name[" + suffix + "]")
        if comment is None:
            comment = entry.get("Comment[" + suffix + "]")

    name = (name or entry.get("Name") or os.path.splitext(os.path.basename(path))[0]).strip()
    comment = (comment or entry.get("Comment") or entry.get("GenericName") or "").strip()

    return {
        "id": path,
        "name": name,
        "comment": comment,
        "icon": entry.get("Icon", "").strip(),
        "exec": command,
        "terminal": entry.get("Terminal", "").strip().lower() == "true",
        "workdir": entry.get("Path", "").strip(),
    }


def collect():
    hidden = read_hidden()
    found = {}
    for directory in applications_dirs():
        try:
            names = sorted(os.listdir(directory))
        except OSError:
            continue
        for name in names:
            if not name.endswith(".desktop"):
                continue
            path = os.path.join(directory, name)
            if path in found or path in hidden:
                continue
            entry = parse_entry(path)
            if entry is not None:
                found[path] = entry
    return sorted(found.values(), key=lambda item: item["name"].lower())


def expand_exec(command):
    command = command.replace("%%", "\x00")
    command = re.sub(r"%[a-zA-Z]", "", command)
    command = command.replace("\x00", "%")
    try:
        return shlex.split(command)
    except ValueError:
        return []


def find_terminal():
    terminal = os.environ.get("TERMINAL", "")
    if terminal and shutil.which(terminal):
        return terminal
    for candidate in ("kitty", "foot", "alacritty", "wezterm", "xterm"):
        if shutil.which(candidate):
            return candidate
    return ""


def cmd_list(_args):
    print(json.dumps({"apps": collect()}, ensure_ascii=False))
    return 0


def cmd_launch(args):
    entry = parse_entry(args.path)
    if entry is None:
        return 1

    command = expand_exec(entry["exec"])
    if not command:
        return 1
    if entry["terminal"]:
        terminal = find_terminal()
        if not terminal:
            return 1
        command = [terminal] + command

    subprocess.Popen(
        command,
        cwd=entry["workdir"] or HOME,
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return 0


def cmd_hide(args):
    hidden = read_hidden()
    hidden.add(args.path)
    write_hidden(hidden)
    return 0


def cmd_reveal(args):
    directory = os.path.dirname(args.path) or HOME
    opener = ""
    if shutil.which("nemo"):
        opener = "nemo"
    elif shutil.which("xdg-open"):
        opener = "xdg-open"
    if not opener:
        return 1

    subprocess.Popen(
        [opener, directory],
        start_new_session=True,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return 0


def main():
    parser = argparse.ArgumentParser(description="BoomShell launcher backend")
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("list").set_defaults(func=cmd_list)

    launch_parser = subparsers.add_parser("launch")
    launch_parser.add_argument("path")
    launch_parser.set_defaults(func=cmd_launch)

    hide_parser = subparsers.add_parser("hide")
    hide_parser.add_argument("path")
    hide_parser.set_defaults(func=cmd_hide)

    reveal_parser = subparsers.add_parser("reveal")
    reveal_parser.add_argument("path")
    reveal_parser.set_defaults(func=cmd_reveal)

    args = parser.parse_args()
    try:
        return args.func(args)
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
