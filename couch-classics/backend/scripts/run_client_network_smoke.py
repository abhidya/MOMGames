#!/usr/bin/env python3
import os
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
CLIENT = ROOT / "client"
BASE_URL = "http://127.0.0.1:8099"


def main() -> int:
    with tempfile.TemporaryDirectory(prefix="couch-classics-pb-") as data_dir:
        subprocess.run(
            [
                "pocketbase",
                "migrate",
                "up",
                "--dir",
                data_dir,
                "--migrationsDir",
                str(BACKEND / "pb_migrations"),
            ],
            cwd=BACKEND,
            check=True,
            stdout=subprocess.DEVNULL,
        )

        server = subprocess.Popen(
            [
                "pocketbase",
                "serve",
                "--http",
                "127.0.0.1:8099",
                "--dir",
                data_dir,
                "--hooksDir",
                str(BACKEND / "pb_hooks"),
                "--migrationsDir",
                str(BACKEND / "pb_migrations"),
            ],
            cwd=BACKEND,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            wait_for_server()
            env = os.environ.copy()
            env["COUCH_CLASSICS_PB_URL"] = BASE_URL
            return subprocess.run(
                [
                    "godot",
                    "--headless",
                    "--path",
                    str(CLIENT),
                    "--script",
                    "tests/network_turn_smoke.gd",
                ],
                cwd=ROOT.parent,
                env=env,
                check=False,
            ).returncode
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()


def wait_for_server() -> None:
    for _ in range(60):
        try:
            with urllib.request.urlopen(BASE_URL + "/api/health", timeout=2):
                return
        except Exception:
            time.sleep(0.2)
    raise RuntimeError("PocketBase test server did not start")


if __name__ == "__main__":
    sys.exit(main())
