"""Durable structured workflow sessions; SQLite serializes local writer access."""
import json
import os
import sqlite3
from collections.abc import MutableMapping
from pathlib import Path


_PRIVATE_FIELDS = {"messages", "prompt", "chain_of_thought", "authorization", "accessToken", "refreshToken", "api_key", "password"}


def clean_state(value):
    """Recursively exclude prompts and credentials at every persistence boundary."""
    if isinstance(value, dict):
        return {k: clean_state(v) for k, v in value.items() if k not in _PRIVATE_FIELDS}
    if isinstance(value, (list, tuple)):
        return [clean_state(item) for item in value]
    return value


class SessionStore(MutableMapping):
    def __init__(self, path=None):
        self.path = str(path or os.environ.get("AMIC_WORKFLOW_DB", Path(__file__).with_name("workflow_state.sqlite3")))
        with self._connect() as connection:
            connection.execute("CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, state TEXT NOT NULL)")

    def _connect(self):
        return sqlite3.connect(self.path, timeout=10)

    def __getitem__(self, key):
        with self._connect() as connection:
            row = connection.execute("SELECT state FROM sessions WHERE id = ?", (key,)).fetchone()
        if row is None:
            raise KeyError(key)
        return json.loads(row[0])

    def __setitem__(self, key, state):
        # Persist structured application state only; never LangChain messages or prompts.
        clean = clean_state(state)
        encoded = json.dumps(clean, default=str)
        with self._connect() as connection:
            connection.execute("INSERT INTO sessions VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET state=excluded.state", (key, encoded))

    def __delitem__(self, key):
        with self._connect() as connection:
            if connection.execute("DELETE FROM sessions WHERE id = ?", (key,)).rowcount == 0:
                raise KeyError(key)

    def __iter__(self):
        with self._connect() as connection:
            keys = [row[0] for row in connection.execute("SELECT id FROM sessions")]
        return iter(keys)

    def __len__(self):
        with self._connect() as connection:
            return connection.execute("SELECT COUNT(*) FROM sessions").fetchone()[0]
