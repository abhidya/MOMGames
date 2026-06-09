#!/usr/bin/env python3
import json
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
BASE_URL = "http://127.0.0.1:8099"
PASSWORD = "couchclassics123"


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
                str(ROOT / "pb_migrations"),
            ],
            cwd=ROOT,
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
                str(ROOT / "pb_hooks"),
                "--migrationsDir",
                str(ROOT / "pb_migrations"),
            ],
            cwd=ROOT,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        try:
            wait_for_server()
            alice = auth("alice@example.test")
            bob = auth("bob@example.test")
            bob_lookup = find_user(alice["token"], "bob")
            assert bob_lookup["id"] == bob["record"]["id"], "handle lookup returned wrong user"

            match = create_match(alice, bob)
            bob_matches = list_matches(bob["token"])
            assert any(item["id"] == match["id"] for item in bob_matches), "bob cannot list invited match"

            move = create_move(alice, bob, match)
            updated = get_match(bob["token"], match["id"])
            assert updated["current_turn"] == bob["record"]["id"], "match current_turn was not flipped"
            assert updated["state"]["turn_number"] == 2, "match state was not updated by hook"
            assert move["turn_number"] == 1, "move turn_number changed unexpectedly"

            notifications = list_notifications(bob["token"])
            assert any(item["match"] == match["id"] for item in notifications), "turn notification was not queued"
            assert patch_match_rejected(alice["token"], match["id"]), "direct match update was allowed"

            print("backend_turn_passing_smoke: ok")
            return 0
        finally:
            server.terminate()
            try:
                server.wait(timeout=5)
            except subprocess.TimeoutExpired:
                server.kill()


def wait_for_server() -> None:
    for _ in range(60):
        try:
            request("GET", "/api/health")
            return
        except Exception:
            time.sleep(0.2)
    raise RuntimeError("PocketBase test server did not start")


def auth(identity: str) -> dict:
    return request(
        "POST",
        "/api/collections/users/auth-with-password",
        {"identity": identity, "password": PASSWORD},
    )


def find_user(token: str, handle: str) -> dict:
    filter_expr = urllib.parse.quote(f"handle = '{handle}'")
    data = request("GET", f"/api/collections/users/records?perPage=1&filter={filter_expr}", token=token)
    items = data.get("items", [])
    assert items, f"user @{handle} not found"
    return items[0]


def create_match(alice: dict, bob: dict) -> dict:
    alice_id = alice["record"]["id"]
    bob_id = bob["record"]["id"]
    return request(
        "POST",
        "/api/collections/matches/records",
        {
            "game_id": "checkers",
            "players": [alice_id, bob_id],
            "created_by": alice_id,
            "current_turn": alice_id,
            "state": {
                "turn_number": 1,
                "players": [
                    {"id": alice_id, "display_name": "Alice"},
                    {"id": bob_id, "display_name": "Bob"},
                ],
            },
            "status": "active",
        },
        token=alice["token"],
    )


def create_move(alice: dict, bob: dict, match: dict) -> dict:
    alice_id = alice["record"]["id"]
    bob_id = bob["record"]["id"]
    return request(
        "POST",
        "/api/collections/moves/records",
        {
            "match": match["id"],
            "player": alice_id,
            "turn_number": 1,
            "move": {"player_id": alice_id, "from": [5, 0], "to": [4, 1]},
            "resulting_state": {"turn_number": 2},
            "next_turn": bob_id,
            "status_after": "active",
        },
        token=alice["token"],
    )


def list_matches(token: str) -> list:
    return request(
        "GET",
        "/api/collections/matches/records?perPage=50&expand=players,current_turn,winner,created_by",
        token=token,
    ).get("items", [])


def list_notifications(token: str) -> list:
    return request("GET", "/api/collections/notification_stubs/records?perPage=50", token=token).get("items", [])


def get_match(token: str, match_id: str) -> dict:
    return request("GET", f"/api/collections/matches/records/{match_id}", token=token)


def patch_match_rejected(token: str, match_id: str) -> bool:
    try:
        request("PATCH", f"/api/collections/matches/records/{match_id}", {"status": "finished"}, token=token)
    except urllib.error.HTTPError as exc:
        return exc.code in {403, 404}
    return False


def request(method: str, path: str, body: dict | None = None, token: str | None = None) -> dict:
    headers = {"Accept": "application/json"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    if token:
        headers["Authorization"] = token
    req = urllib.request.Request(BASE_URL + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=10) as response:
            raw = response.read().decode()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        print(f"{method} {path} -> HTTP {exc.code}: {detail}", file=sys.stderr)
        raise
    return json.loads(raw) if raw else {}


if __name__ == "__main__":
    sys.exit(main())
