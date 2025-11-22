# Persistent storage for the CLI application
# Dummy Data is stored in separate JSON files under python/dummy-data
# Importing necessary modules
from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any, Dict

DEFAULT_DATA_DIR = Path(__file__).resolve().parent / "dummy-data"   # Set Default Data Directory
DATA_DIR = Path(os.environ.get("ITAM_DATA_DIR", DEFAULT_DATA_DIR))

USERS_FILE = DATA_DIR / "users.json"   # Set Users File Path
ITEMS_FILE = DATA_DIR / "items.json"   # Set Items File Path


def _ensure_path(path: Path, default: Dict[str, Any]) -> None:  # Ensure the path exists
    path.parent.mkdir(parents=True, exist_ok=True)
    if not path.exists():
        with path.open("w", encoding="utf-8") as handle:
            json.dump(default, handle, indent=2)


def _load_json(path: Path, default: Dict[str, Any]) -> Dict[str, Any]:  # Load JSON data from the file
    _ensure_path(path, default)
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _save_json(path: Path, data: Dict[str, Any]) -> None:  # Save JSON data to the file
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)


def load_users() -> Dict[str, Any]: # Load users database from the file
    return _load_json(USERS_FILE, {})


def save_users(users: Dict[str, Any]) -> None: # Save users database to the file
    _save_json(USERS_FILE, users)


def load_items() -> Dict[str, Any]: # Load items database from the file
    return _load_json(ITEMS_FILE, {})


def save_items(items: Dict[str, Any]) -> None: # Save items database to the file
    _save_json(ITEMS_FILE, items)

