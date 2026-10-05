"""Small helpers used by the fakeflix roles."""

import copy
import json
import posixpath

MASKED = "********"


def media_app_path(path, mounts):
    """Translate a host path to the path the apps see, using the longest
    matching host prefix in ``mounts`` ({host_path: container_path}).
    Returns None when the path is not under any mount."""
    path = posixpath.normpath(path)
    best = None
    for src, dst in mounts.items():
        src = posixpath.normpath(src)
        if path == src or path.startswith(src.rstrip("/") + "/"):
            if best is None or len(src) > len(best[0]):
                best = (src, dst)
    if best is None:
        return None
    rest = path[len(best[0]):].lstrip("/")
    return posixpath.join(best[1], rest) if rest else best[1]


def _split_port(spec):
    spec = str(spec).split("/")[0]
    parts = spec.split(":")
    return parts[-2] if len(parts) > 1 else parts[-1], parts[-1]


def host_port(service):
    """First published host port of a catalog service."""
    return _split_port(service["ports"][0])[0]


def container_port(service):
    """Container side of the first published port of a catalog service."""
    return _split_port(service["ports"][0])[1]


def base_path(service):
    """Path prefix the app itself serves under ("" if none). Apps behind a
    stripping proxy or on their own subdomain serve at the root."""
    web = service.get("web") or {}
    path = (web.get("path") or "").rstrip("/")
    if not path or web.get("strip_prefix") or web.get("subdomain"):
        return ""
    return path


def service_urls(services, host=None):
    """{name: url} for catalog items (dict2items form) that publish a port.
    With ``host``: URL via the published port on that host. Without: the
    container-to-container URL (http://<name>:<container port>). Both include
    the app's base path."""
    urls = {}
    for item in services:
        svc = item["value"]
        if not svc.get("ports"):
            continue
        if host:
            urls[item["key"]] = "http://%s:%s%s" % (host, host_port(svc), base_path(svc))
        else:
            urls[item["key"]] = "http://%s:%s%s" % (item["key"], container_port(svc), base_path(svc))
    return urls


def public_url(service, domain, scheme="http"):
    """URL of a catalog service through the reverse proxy, or None."""
    web = service.get("web")
    if not web:
        return None
    if web.get("subdomain"):
        return "%s://%s.%s" % (scheme, web["subdomain"], domain)
    path = (web.get("path") or "/").rstrip("/")
    return "%s://%s%s" % (scheme, domain, path or "")


def arr_pick_schema(schemas, implementation=None, match=None):
    """Pick one entry of a Servarr */schema response (strings compared
    case-insensitively)."""
    match = dict(match or {})
    if implementation:
        match["implementation"] = implementation

    def same(a, b):
        if isinstance(a, str) and isinstance(b, str):
            return a.lower() == b.lower()
        return a == b

    for item in schemas:
        if all(same(item.get(k), v) for k, v in match.items()):
            return item
    raise ValueError(
        "nothing in the app's schema matches %s. Check the name; for Prowlarr "
        "indexers the host must also be able to reach indexers.prowlarr.com "
        "to download indexer definitions." % match
    )


def arr_apply(base, name, fields=None, body=None):
    """Return ``base`` (schema entry or existing resource) with name, field
    values and top-level keys set."""
    out = copy.deepcopy(base)
    out["name"] = name
    fields = fields or {}
    known = set()
    for field in out.get("fields", []):
        known.add(field["name"])
        if field["name"] in fields:
            field["value"] = fields[field["name"]]
    missing = set(fields) - known
    if missing:
        raise ValueError("unknown field(s) %s for %s" % (sorted(missing), name))
    out.update(copy.deepcopy(body or {}))
    return out


def arr_differs(current, desired):
    """True when ``current`` (from the API) lacks something in ``desired``.
    Masked secrets ("********") can't be compared and count as equal."""
    for key, value in desired.items():
        if key == "fields":
            have = {f["name"]: f.get("value") for f in current.get("fields", [])}
            for field in value:
                cur = have.get(field["name"])
                if cur == MASKED:
                    continue
                if cur != field.get("value") and not (cur in (None, "") and field.get("value") in (None, "")):
                    return True
        elif current.get(key) != value:
            return True
    return False


def dict_differs(current, desired):
    """True when any (nested) key of ``desired`` has another value in ``current``.
    Lists are compared ignoring order."""
    if isinstance(desired, dict):
        if not isinstance(current, dict):
            return True
        return any(dict_differs(current.get(k), v) for k, v in desired.items())
    if isinstance(desired, list) and isinstance(current, list):
        try:
            return sorted(current) != sorted(desired)
        except TypeError:
            return current != desired
    return current != desired


def bazarr_form(settings, languages=None):
    """{section: {key: value}} -> [(settings-section-key, value), ...] as the
    Bazarr settings form expects (lists become repeated keys). With
    ``languages`` (ISO 639-1 codes) also enable them and create language
    profile 1 containing all of them."""
    pairs = []
    if languages:
        pairs += [("languages-enabled", code) for code in languages]
        profile = {
            "profileId": 1,
            "name": " + ".join(languages),
            "cutoff": None,
            "items": [
                {"id": i, "language": code, "audio_exclude": "False", "hi": "False", "forced": "False"}
                for i, code in enumerate(languages, 1)
            ],
            "mustContain": [],
            "mustNotContain": [],
            "originalFormat": False,
            "tag": None,
        }
        pairs.append(("languages-profiles", json.dumps([profile])))
    for section, values in settings.items():
        for key, value in values.items():
            name = "settings-%s-%s" % (section, key)
            for v in value if isinstance(value, list) else [value]:
                if isinstance(v, bool):
                    v = "true" if v else "false"
                pairs.append((name, str(v)))
    return pairs


class FilterModule(object):
    def filters(self):
        return {
            "media_app_path": media_app_path,
            "host_port": host_port,
            "container_port": container_port,
            "service_urls": service_urls,
            "base_path": base_path,
            "public_url": public_url,
            "arr_pick_schema": arr_pick_schema,
            "arr_apply": arr_apply,
            "arr_differs": arr_differs,
            "dict_differs": dict_differs,
            "bazarr_form": bazarr_form,
        }
