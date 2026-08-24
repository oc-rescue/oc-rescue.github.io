#!/usr/bin/env python3
"""Update OpenCore Rescue from the latest official OCLP release."""

from __future__ import annotations

import ast
import json
import os
import re
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
REPOSITORY = "dortania/OpenCore-Legacy-Patcher"
API_RELEASE = f"https://api.github.com/repos/{REPOSITORY}/releases/latest"


def request(url: str) -> bytes:
    headers = {
        "Accept": "application/vnd.github+json",
        "User-Agent": "oc-rescue-catalog-updater",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as response:
        return response.read()


def assignment(tree: ast.Module, name: str) -> ast.AST:
    for node in tree.body:
        if not isinstance(node, (ast.Assign, ast.AnnAssign)):
            continue
        targets = node.targets if isinstance(node, ast.Assign) else [node.target]
        if any(isinstance(target, ast.Name) and target.id == name for target in targets):
            return node.value
    raise RuntimeError(f"Missing assignment: {name}")


def supported_models(source: str) -> list[str]:
    node = assignment(ast.parse(source), "SupportedSMBIOS")
    if not isinstance(node, (ast.List, ast.Tuple)):
        raise RuntimeError("SupportedSMBIOS is not a list")
    models = [item.value for item in node.elts if isinstance(item, ast.Constant) and isinstance(item.value, str)]
    if not models:
        raise RuntimeError("No supported models found")
    return models


def marketing_names(source: str) -> dict[str, str]:
    node = assignment(ast.parse(source), "smbios_dictionary")
    if not isinstance(node, ast.Dict):
        raise RuntimeError("smbios_dictionary is not a dictionary")
    result: dict[str, str] = {}
    for key, value in zip(node.keys, node.values):
        if not isinstance(key, ast.Constant) or not isinstance(key.value, str) or not isinstance(value, ast.Dict):
            continue
        for field, field_value in zip(value.keys, value.values):
            if (
                isinstance(field, ast.Constant)
                and field.value == "Marketing Name"
                and isinstance(field_value, ast.Constant)
                and isinstance(field_value.value, str)
            ):
                result[key.value] = field_value.value
                break
    return result


def family(model_id: str) -> str:
    for prefix, label in (
        ("MacBookAir", "MacBook Air"),
        ("MacBookPro", "MacBook Pro"),
        ("MacBook", "MacBook"),
        ("Macmini", "Mac mini"),
        ("MacPro", "Mac Pro"),
        ("iMac", "iMac"),
        ("Xserve", "Xserve"),
    ):
        if model_id.startswith(prefix):
            return label
    return "Other"


def french_name(name: str) -> str:
    replacements = (
        ("Four Thunderbolt 3 Ports", "quatre ports Thunderbolt 3"),
        ("Four Thunderbolt 3 ports", "quatre ports Thunderbolt 3"),
        ("Two Thunderbolt 3 ports", "deux ports Thunderbolt 3"),
        ("Early ", "début "),
        ("Mid ", "mi-"),
        ("Late ", "fin "),
        ("-inch", " pouces"),
        ("Aluminum", "Aluminium"),
        ("Original", "Original"),
        ("original", "original"),
    )
    translated = name
    for source, target in replacements:
        translated = translated.replace(source, target)
    return translated


def main() -> None:
    release = json.loads(request(API_RELEASE))
    tag = release["tag_name"]
    if not re.fullmatch(r"[A-Za-z0-9._-]+", tag):
        raise RuntimeError(f"Unsafe release tag: {tag}")

    package = next((asset for asset in release["assets"] if asset["name"] == "OpenCore-Patcher.pkg"), None)
    if not package:
        raise RuntimeError("OpenCore-Patcher.pkg is missing from the latest release")
    digest = package.get("digest", "")
    if not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise RuntimeError("The official release does not expose a valid SHA-256 digest")

    raw_base = f"https://raw.githubusercontent.com/{REPOSITORY}/{tag}/opencore_legacy_patcher/datasets"
    model_source = request(f"{raw_base}/model_array.py").decode("utf-8")
    smbios_source = request(f"{raw_base}/smbios_data.py").decode("utf-8")
    model_ids = supported_models(model_source)
    names = marketing_names(smbios_source)

    missing = [model_id for model_id in model_ids if model_id not in names]
    if missing:
        raise RuntimeError(f"Missing marketing names: {', '.join(missing)}")

    catalog = {
        "schema": 1,
        "source": f"https://github.com/{REPOSITORY}",
        "source_tag": tag,
        "published_at": release.get("published_at"),
        "release": {
            "version": tag,
            "url": release["html_url"],
            "package_url": package["browser_download_url"],
            "sha256": digest.removeprefix("sha256:"),
            "package_size": package["size"],
        },
        "models": [
            {
                "id": model_id,
                "family": family(model_id),
                "name_en": names[model_id],
                "name_fr": french_name(names[model_id]),
            }
            for model_id in model_ids
        ],
    }

    DATA_DIR.mkdir(parents=True, exist_ok=True)
    json_text = json.dumps(catalog, ensure_ascii=False, indent=2) + "\n"
    (DATA_DIR / "catalog.json").write_text(json_text, encoding="utf-8")
    (DATA_DIR / "catalog.js").write_text(
        "window.OCRESCUE_CATALOG = " + json_text.rstrip() + ";\n",
        encoding="utf-8",
    )
    supported = ";".join(model_ids)
    release_text = "\n".join(
        (
            f"OCLP_VERSION={tag}",
            f"OCLP_URL={package['browser_download_url']}",
            f"OCLP_SHA256={digest.removeprefix('sha256:')}",
            f"OCLP_SIZE={package['size']}",
            f"SUPPORTED_MODELS={supported}",
            "",
        )
    )
    (DATA_DIR / "oclp-release.txt").write_text(release_text, encoding="ascii")
    print(f"Updated OCLP {tag}: {len(model_ids)} supported models")


if __name__ == "__main__":
    main()
