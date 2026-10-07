from __future__ import annotations

import json
import os
from contextlib import contextmanager
from pathlib import Path
from typing import Iterable


class AtomicStateError(RuntimeError):
    pass


@contextmanager
def _exclusive_lock(lock_path: Path):
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    fh = lock_path.open("a+b")
    try:
        fh.seek(0, os.SEEK_END)
        if fh.tell() == 0:
            fh.write(b"\0")
            fh.flush()
        fh.seek(0)
        if os.name == "nt":
            import msvcrt
            msvcrt.locking(fh.fileno(), msvcrt.LK_LOCK, 1)
        else:
            import fcntl
            fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        try:
            yield
        finally:
            fh.seek(0)
            if os.name == "nt":
                import msvcrt
                msvcrt.locking(fh.fileno(), msvcrt.LK_UNLCK, 1)
            else:
                import fcntl
                fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    finally:
        fh.close()


def _load(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise AtomicStateError("ATOMIC_STATE_INVALID") from exc
    if not isinstance(value, dict):
        raise AtomicStateError("ATOMIC_STATE_INVALID")
    return value


def _durable_write(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_name(path.name + ".tmp")
    payload = (json.dumps(value, indent=2, sort_keys=True) + "\n").encode("utf-8")
    with tmp.open("wb") as fh:
        fh.write(payload)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, path)
    if os.name != "nt":
        try:
            dir_fd = os.open(str(path.parent), os.O_RDONLY)
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError:
            pass


def atomic_consume(path: Path, field: str, values: Iterable[str]) -> str | None:
    normalized = [str(v) for v in values]
    if not normalized or any(not v for v in normalized):
        raise AtomicStateError("ATOMIC_CONSUME_VALUE_INVALID")
    lock_path = path.with_name(path.name + ".lock")
    with _exclusive_lock(lock_path):
        state = _load(path)
        existing_raw = state.get(field, [])
        if not isinstance(existing_raw, list):
            raise AtomicStateError("ATOMIC_STATE_FIELD_INVALID")
        existing = set(str(v) for v in existing_raw)
        for value in normalized:
            if value in existing:
                return value
        existing.update(normalized)
        state[field] = sorted(existing)
        _durable_write(path, state)
    return None
