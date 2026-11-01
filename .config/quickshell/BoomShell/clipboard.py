#!/usr/bin/env python3
"""Clipboard history backend for the BoomShell clipboard panel.

The history itself lives in clipvault's SQLite database, which is filled by
`wl-paste --watch clipvault store`. This helper only lists/updates that
database and extracts image blobs into a cache directory for previews.
"""

import argparse
import json
import os
import sqlite3
import subprocess
import sys
import time

RETENTION_DAYS = 7
DEFAULT_LIMIT = 200
IMAGE_EXTENSIONS = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/webp": "webp",
    "image/gif": "gif",
    "image/bmp": "bmp",
}

DB_PATH = os.path.abspath(
    os.environ.get("CLIPVAULT_DB") or os.path.expanduser("~/.local/share/clipvault.db")
)
CACHE_DIR = os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"),
    "boomclip",
)


def connect(write=False):
    mode = "rw" if write else "ro"
    connection = sqlite3.connect(f"file:{DB_PATH}?mode={mode}", uri=True, timeout=5)
    connection.execute("PRAGMA busy_timeout = 5000")
    return connection


def clean_cache(connection):
    if not os.path.isdir(CACHE_DIR):
        return
    alive = {str(row[0]) for row in connection.execute("SELECT id FROM clipboard")}
    for name in os.listdir(CACHE_DIR):
        stem, dot, _ = name.partition(".")
        if dot and stem.isdigit() and stem not in alive:
            try:
                os.remove(os.path.join(CACHE_DIR, name))
            except OSError:
                pass


def prune(connection):
    cutoff = int(time.time()) - RETENTION_DAYS * 24 * 60 * 60
    deleted = connection.execute(
        "DELETE FROM clipboard WHERE last_updated < ?", (cutoff,)
    ).rowcount
    connection.commit()
    clean_cache(connection)
    return deleted


def cmd_list(args):
    if not os.path.exists(DB_PATH):
        print(json.dumps({"items": [], "total": 0}))
        return 0

    connection = connect(write=True)
    prune(connection)

    rows = connection.execute(
        """
        SELECT id, content, last_updated, content_type, mimetype, extra_preview_data
        FROM clipboard
        ORDER BY last_updated DESC
        LIMIT ?
        """,
        (args.limit,),
    ).fetchall()

    items = []
    for item_id, content, updated, content_type, mimetype, extra in rows:
        if content_type == 0:
            mime = (mimetype or "image/png").split(";")[0]
            extension = IMAGE_EXTENSIONS.get(mime, "bin")
            path = os.path.join(CACHE_DIR, f"{item_id}.{extension}")
            if not os.path.exists(path):
                os.makedirs(CACHE_DIR, exist_ok=True)
                with open(path, "wb") as handle:
                    handle.write(content)

            width = height = 0
            if extra:
                try:
                    width, height = (int(value) for value in extra.lower().split("x", 1))
                except (TypeError, ValueError):
                    width = height = 0

            items.append(
                {
                    "id": item_id,
                    "kind": "image",
                    "mime": mime,
                    "path": path,
                    "preview": "",
                    "w": width,
                    "h": height,
                    "ts": updated,
                    "size": len(content),
                }
            )
        else:
            text = content.decode("utf-8", "replace")
            items.append(
                {
                    "id": item_id,
                    "kind": "text",
                    "mime": "text/plain",
                    "path": "",
                    "preview": text.strip()[:400],
                    "chars": len(text),
                    "ts": updated,
                    "size": len(content),
                }
            )

    total = connection.execute("SELECT count(*) FROM clipboard").fetchone()[0]
    print(json.dumps({"items": items, "total": total}, ensure_ascii=False))
    return 0


def cmd_copy(args):
    connection = connect()
    row = connection.execute(
        "SELECT content, content_type, mimetype FROM clipboard WHERE id = ?", (args.id,)
    ).fetchone()
    if row is None:
        return 1

    content, content_type, mimetype = row
    command = ["wl-copy"]
    if content_type == 0 and mimetype:
        command += ["--type", mimetype.split(";")[0]]

    return subprocess.run(command, input=content).returncode


def cmd_delete(args):
    connection = connect(write=True)
    connection.execute("DELETE FROM clipboard WHERE id = ?", (args.id,))
    connection.commit()
    clean_cache(connection)
    return 0


def cmd_clear(_args):
    connection = connect(write=True)
    connection.execute("DELETE FROM clipboard")
    connection.commit()
    clean_cache(connection)
    return 0


def cmd_prune(_args):
    if not os.path.exists(DB_PATH):
        print("0")
        return 0
    connection = connect(write=True)
    print(prune(connection))
    return 0


def main():
    parser = argparse.ArgumentParser(description="BoomShell clipboard history helper")
    subparsers = parser.add_subparsers(dest="command", required=True)

    list_parser = subparsers.add_parser("list")
    list_parser.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    list_parser.set_defaults(func=cmd_list)

    copy_parser = subparsers.add_parser("copy")
    copy_parser.add_argument("id", type=int)
    copy_parser.set_defaults(func=cmd_copy)

    delete_parser = subparsers.add_parser("delete")
    delete_parser.add_argument("id", type=int)
    delete_parser.set_defaults(func=cmd_delete)

    subparsers.add_parser("clear").set_defaults(func=cmd_clear)
    subparsers.add_parser("prune").set_defaults(func=cmd_prune)

    args = parser.parse_args()
    try:
        return args.func(args)
    except (sqlite3.Error, OSError) as error:
        print(str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
