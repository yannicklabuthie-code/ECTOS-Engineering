from __future__ import annotations

import base64
import hashlib
from typing import Any, Dict


class AuthorityCryptoError(ValueError):
    pass


_SHA256_DIGESTINFO_PREFIX = bytes.fromhex("3031300d060960864801650304020105000420")


def _b64url_decode(value: str) -> bytes:
    if not isinstance(value, str) or not value:
        raise AuthorityCryptoError("SIGNATURE_MISSING")
    try:
        return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
    except Exception as exc:
        raise AuthorityCryptoError("SIGNATURE_ENCODING_INVALID") from exc


def _public_numbers(public_key: Dict[str, Any]) -> tuple[int, int]:
    if not isinstance(public_key, dict):
        raise AuthorityCryptoError("PUBLIC_KEY_INVALID")
    if public_key.get("algorithm") != "RSA-PKCS1-v1_5-SHA256":
        raise AuthorityCryptoError("PUBLIC_KEY_ALGORITHM_INVALID")
    if public_key.get("key_use") != "VERIFY_ONLY":
        raise AuthorityCryptoError("PUBLIC_KEY_USE_INVALID")
    if any(name in public_key for name in ("d", "private_exponent", "private_key", "secret")):
        raise AuthorityCryptoError("PRIVATE_SIGNING_MATERIAL_PROHIBITED_IN_VERIFIER")
    n_hex = public_key.get("n_hex")
    e = public_key.get("e")
    if not isinstance(n_hex, str) or not n_hex:
        raise AuthorityCryptoError("PUBLIC_KEY_MODULUS_INVALID")
    try:
        n = int(n_hex, 16)
    except ValueError as exc:
        raise AuthorityCryptoError("PUBLIC_KEY_MODULUS_INVALID") from exc
    if not isinstance(e, int) or isinstance(e, bool) or e < 3 or e % 2 == 0:
        raise AuthorityCryptoError("PUBLIC_KEY_EXPONENT_INVALID")
    if n.bit_length() < 2048:
        raise AuthorityCryptoError("PUBLIC_KEY_TOO_SMALL")
    return n, e


def public_key_fingerprint(public_key: Dict[str, Any]) -> str:
    n, e = _public_numbers(public_key)
    return hashlib.sha256(f"{n:x}:{e}".encode("ascii")).hexdigest()


def verify_rsa_pkcs1_v1_5_sha256(message: bytes, signature_b64url: str, public_key: Dict[str, Any]) -> None:
    n, e = _public_numbers(public_key)
    signature = _b64url_decode(signature_b64url)
    k = (n.bit_length() + 7) // 8
    if len(signature) != k:
        raise AuthorityCryptoError("SIGNATURE_LENGTH_INVALID")
    s = int.from_bytes(signature, "big")
    if s <= 0 or s >= n:
        raise AuthorityCryptoError("SIGNATURE_VALUE_INVALID")
    encoded = pow(s, e, n).to_bytes(k, "big")
    digest_info = _SHA256_DIGESTINFO_PREFIX + hashlib.sha256(message).digest()
    padding_len = k - len(digest_info) - 3
    if padding_len < 8:
        raise AuthorityCryptoError("PUBLIC_KEY_TOO_SMALL")
    expected = b"\x00\x01" + (b"\xff" * padding_len) + b"\x00" + digest_info
    if encoded != expected:
        raise AuthorityCryptoError("SIGNATURE_INVALID")
