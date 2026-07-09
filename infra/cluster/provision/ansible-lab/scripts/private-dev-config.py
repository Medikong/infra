#!/usr/bin/env python3
import json
import shlex
import sys
from pathlib import Path


def parse_scalar(raw):
    value = raw.strip()
    if value == "":
        return ""
    if value in {"true", "false"}:
        return value == "true"
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1]
    try:
        return int(value)
    except ValueError:
        return value


def parse_simple_yaml(path):
    root = {}
    stack = [(-1, root)]
    for lineno, line in enumerate(Path(path).read_text().splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        if indent % 2 != 0:
            raise SystemExit(f"{path}:{lineno}: indentation must use two spaces")
        if ":" not in stripped:
            raise SystemExit(f"{path}:{lineno}: expected key: value")
        key, raw_value = stripped.split(":", 1)
        key = key.strip()
        while stack and indent <= stack[-1][0]:
            stack.pop()
        parent = stack[-1][1]
        if raw_value.strip() == "":
            node = {}
            parent[key] = node
            stack.append((indent, node))
        else:
            parent[key] = parse_scalar(raw_value)
    return root


def get_value(data, dotted):
    current = data
    for part in dotted.split("."):
        current = current[part]
    return current


def as_text(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    return str(value)


def shell_assign(name, value):
    return f"{name}={shlex.quote(as_text(value))}"


def main():
    if len(sys.argv) < 3:
        raise SystemExit("usage: private-dev-config.py <value|shell|json> <config> [path]")
    mode = sys.argv[1]
    config = sys.argv[2]
    data = parse_simple_yaml(config)

    if mode == "value":
        if len(sys.argv) != 4:
            raise SystemExit("usage: private-dev-config.py value <config> <path>")
        print(as_text(get_value(data, sys.argv[3])))
        return

    if mode == "json":
        print(json.dumps(data, indent=2, sort_keys=True))
        return

    if mode == "shell":
        pairs = {
            "PRIVATE_DEV_SSH_CONFIG": data["ssh"]["config_path"],
            "PRIVATE_DEV_SSH_KEY": data["ssh"]["key_path"],
            "PRIVATE_DEV_SSH_PASSPHRASE": data["ssh"]["passphrase"],
            "PRIVATE_DEV_SSH_USER": data["ssh"]["user"],
            "PRIVATE_DEV_NODE1_HOST": data["ssh"]["node1"]["host"],
            "PRIVATE_DEV_NODE1_PORT": data["ssh"]["node1"]["port"],
            "PRIVATE_DEV_NODE2_HOST": data["ssh"]["peers"]["node2"],
            "PRIVATE_DEV_NODE3_HOST": data["ssh"]["peers"]["node3"],
            "PRIVATE_DEV_NODE4_HOST": data["ssh"]["peers"]["node4"],
            "PRIVATE_DEV_NODE5_HOST": data["ssh"]["peers"]["node5"],
            "PRIVATE_DEV_NODE6_HOST": data["ssh"]["peers"]["node6"],
            "CLUSTER_ENV": data["cluster"]["env"],
            "ANSIBLE_INVENTORY": data["cluster"]["inventory"],
            "SERVER_OS": data["cluster"]["server_os"],
            "ANSIBLE_FLAGS": data["cluster"]["ansible_flags"],
            "RUN_PRIVATE_DEV_SECRETS": data["cluster"]["run_private_dev_secrets"],
            "RUN_ECR_SECRET": data["cluster"]["run_ecr_secret"],
            "ARGOCD_NAMESPACE": data["argocd"]["namespace"],
            "ARGOCD_INSTALL_MANIFEST_URL": data["argocd"]["install_manifest_url"],
            "ARGOCD_ROOT_APPLICATION_URL": data["argocd"]["root_application_url"],
            "ARGOCD_SERVER_READY_TIMEOUT": data["argocd"]["server_ready_timeout"],
            "ARGOCD_CONTROLLER_READY_TIMEOUT": data["argocd"]["controller_ready_timeout"],
            "ARGOCD_ROOT_APPLICATION_NAME": data["argocd"]["root_application_name"],
        }
        for name, value in pairs.items():
            print(shell_assign(name, value))
        return

    raise SystemExit(f"unknown mode: {mode}")


if __name__ == "__main__":
    main()
