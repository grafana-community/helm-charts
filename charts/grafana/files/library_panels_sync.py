import base64
import json
import os
import ssl
import sys
import time
from pathlib import Path
from urllib import error, parse, request


def log(message):
    print(message, flush=True)


def decode_json(raw):
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return None


def unwrap_payload(payload):
    if isinstance(payload, dict):
        for key in ("result", "libraryElement", "libraryPanel"):
            nested = payload.get(key)
            if isinstance(nested, dict):
                return nested
    return payload


def load_payload(path):
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        log(f"Skipping {path}: file disappeared before it could be processed")
        return None
    except json.JSONDecodeError as exc:
        log(f"Skipping {path}: invalid JSON ({exc})")
        return None

    payload = unwrap_payload(payload)
    if not isinstance(payload, dict):
        log(f"Skipping {path}: JSON root must be an object")
        return None

    uid = payload.get("uid")
    if not uid:
        log(f"Skipping {path}: no 'uid' field found")
        return None

    return payload


def sanitize_payload(payload, existing=None):
    payload = dict(payload)
    payload.pop("meta", None)
    payload.pop("folderName", None)

    if existing:
        existing = unwrap_payload(existing)
        if isinstance(existing, dict):
            if existing.get("id") is not None:
                payload["id"] = existing["id"]
            if existing.get("version") is not None:
                payload["version"] = existing["version"]
    else:
        payload.pop("id", None)
        if payload.get("version") is None:
            payload.pop("version", None)

    return payload


grafana_url = os.environ.get("GRAFANA_URL", "http://localhost:3000").rstrip("/")
library_panels_dir = os.environ.get("LIBPANELS_DIR", "/tmp/library-panels")
managed_state_file = os.environ.get("LIBPANELS_STATE_FILE", "/tmp/library-panels/.managed-uids.json")
delete_on_missing = os.environ.get("DELETE_ON_MISSING", "").lower() in {"1", "true", "yes", "on"}
grafana_user = os.environ.get("GRAFANA_USER")
grafana_password = os.environ.get("GRAFANA_PASSWORD")
grafana_token = os.environ.get("GRAFANA_TOKEN")
skip_tls_verify = os.environ.get("SKIP_TLS_VERIFY", "").lower() in {"1", "true", "yes", "on"}
grafana_wait_timeout = int(os.environ.get("GRAFANA_WAIT_TIMEOUT", "120"))
grafana_wait_interval = max(1, int(os.environ.get("GRAFANA_WAIT_INTERVAL", "5")))

headers = {
    "Accept": "application/json",
    "Content-Type": "application/json",
}

if grafana_token:
    headers["Authorization"] = f"Bearer {grafana_token}"
    log("Using Grafana API token authentication")
elif grafana_user and grafana_password:
    basic_auth = base64.b64encode(f"{grafana_user}:{grafana_password}".encode("utf-8")).decode("ascii")
    headers["Authorization"] = f"Basic {basic_auth}"
    log(f"Using Grafana basic authentication (user={grafana_user})")
else:
    log("ERROR: Library panels sync requires either GRAFANA_TOKEN or both GRAFANA_USER and GRAFANA_PASSWORD")
    sys.exit(1)

ssl_context = None
if skip_tls_verify and grafana_url.startswith("https://"):
    ssl_context = ssl._create_unverified_context()


def wait_for_grafana():
    if grafana_wait_timeout <= 0:
        return
    deadline = time.monotonic() + grafana_wait_timeout
    health_url = f"{grafana_url}/api/health"
    log(f"Waiting up to {grafana_wait_timeout}s for Grafana to be ready at {health_url}")
    while True:
        try:
            req = request.Request(health_url, headers={"Accept": "application/json"})
            with request.urlopen(req, context=ssl_context, timeout=10) as resp:
                if resp.status == 200:
                    log("Grafana is ready")
                    return
        except Exception:
            pass
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            log(f"Grafana did not become ready within {grafana_wait_timeout}s, proceeding anyway")
            return
        log(f"Grafana not ready yet, retrying in {grafana_wait_interval}s ({int(remaining)}s remaining)")
        time.sleep(min(grafana_wait_interval, remaining))


def api_request(method, api_path, payload=None):
    request_data = None
    if payload is not None:
        request_data = json.dumps(payload).encode("utf-8")

    req = request.Request(f"{grafana_url}{api_path}", data=request_data, headers=headers, method=method)

    try:
        with request.urlopen(req, context=ssl_context, timeout=30) as response:
            return response.status, response.read().decode("utf-8")
    except error.HTTPError as exc:
        return exc.code, exc.read().decode("utf-8", errors="replace")
    except error.URLError as exc:
        log(f"ERROR: URL error during {method} {api_path}: {exc}")
        return None, str(exc)
    except Exception as exc:
        log(f"ERROR: Unexpected error during {method} {api_path}: {type(exc).__name__}: {exc}")
        return None, str(exc)


def response_message(body):
    payload = decode_json(body)
    if isinstance(payload, dict):
        for key in ("message", "status"):
            value = payload.get(key)
            if value:
                return str(value)
    return body.strip()


def load_managed_uids(path):
    state_path = Path(path)
    if not state_path.exists():
        return set()

    try:
        raw = json.loads(state_path.read_text(encoding="utf-8"))
    except Exception as exc:
        log(f"Ignoring invalid managed UID state at {state_path}: {exc}")
        return set()

    if isinstance(raw, list):
        return {str(uid) for uid in raw if uid}

    return set()


def save_managed_uids(path, uids):
    state_path = Path(path)
    state_path.parent.mkdir(parents=True, exist_ok=True)
    state_path.write_text(json.dumps(sorted(uids)), encoding="utf-8")


managed_state_path = Path(managed_state_file).resolve()
files = sorted(
    path
    for path in Path(library_panels_dir).rglob("*.json")
    if path.is_file() and path.resolve() != managed_state_path
)

wait_for_grafana()

previous_managed_uids = load_managed_uids(managed_state_file)
if files:
    log(f"Syncing {len(files)} library panel file(s) from {library_panels_dir} to {grafana_url}")
else:
    log(f"No JSON files found in {library_panels_dir}")

failures = 0
parse_failures = 0
desired_uids = set()
try:
    for file_path in files:
        payload = load_payload(file_path)
        if payload is None:
            parse_failures += 1
            continue

        uid = str(payload["uid"])
        desired_uids.add(uid)
        log(f"Processing library panel uid={uid} from file={file_path}")

        get_status, get_body = api_request("GET", f"/api/library-elements/{parse.quote(uid, safe='')}")
        if get_status == 404:
            create_payload = sanitize_payload(payload)
            result_status, result_body = api_request("POST", "/api/library-elements", create_payload)
            action = "created"
        elif get_status is not None and 200 <= get_status < 300:
            existing_payload = decode_json(get_body)
            update_payload = sanitize_payload(payload, existing=existing_payload)
            result_status, result_body = api_request("PATCH", f"/api/library-elements/{parse.quote(uid, safe='')}", update_payload)
            action = "updated"
        else:
            failures += 1
            log(f"Failed to query library panel uid={uid}: GET returned status {get_status}: {response_message(get_body)}")
            continue

        if result_status is not None and 200 <= result_status < 300:
            log(f"Successfully {action} library panel uid={uid}")
        else:
            failures += 1
            log(f"Failed to sync library panel uid={uid}: {action.upper()} returned status {result_status}: {response_message(result_body)}")
except Exception as exc:
    log(f"ERROR: Unexpected error during sync: {type(exc).__name__}: {exc}")
    import traceback

    log(traceback.format_exc())
    failures += 1

managed_uids = set(previous_managed_uids)
managed_uids.update(desired_uids)

if delete_on_missing:
    if parse_failures or failures:
        log("Skipping deletion reconciliation because sync had errors")
    else:
        to_delete = sorted(previous_managed_uids - desired_uids)
        for uid in to_delete:
            log(f"Deleting library panel uid={uid} because source file is missing")
            status, body = api_request("DELETE", f"/api/library-elements/{parse.quote(uid, safe='')}")
            if status == 404 or (status is not None and 200 <= status < 300):
                managed_uids.discard(uid)
                log(f"Successfully removed library panel uid={uid}")
            else:
                failures += 1
                log(f"Failed to remove library panel uid={uid}: {response_message(body)}")

save_managed_uids(managed_state_file, managed_uids)

if failures:
    sys.exit(1)

log("Library panel sync completed.")

