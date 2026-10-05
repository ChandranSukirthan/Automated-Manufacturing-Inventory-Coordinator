"""Validate the same signed bearer tokens as the authoritative backend."""
import base64
import binascii
import hashlib
import hmac
import json
import time
from fastapi import Header, HTTPException
from ai.core.config import settings


def require_actor(authorization: str | None = Header(default=None)) -> dict:
    try:
        scheme, token = (authorization or "").split(" ", 1)
        if scheme.lower() != "bearer" or not settings.jwt_secret_key:
            raise ValueError("Missing bearer token or JWT configuration")
        header, payload, signature = token.split(".")
        decode = lambda text: base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))
        if json.loads(decode(header)).get("alg") != "HS256":
            raise ValueError("Unsupported signature")
        expected = hmac.new(settings.jwt_secret_key.encode(), f"{header}.{payload}".encode(), hashlib.sha256).digest()
        if not hmac.compare_digest(expected, decode(signature)):
            raise ValueError("Invalid signature")
        claims = json.loads(decode(payload))
        if float(claims.get("exp", 0)) <= time.time() or float(claims.get("nbf", 0)) > time.time() + 30:
            raise ValueError("Expired token")
        audiences = claims.get("aud", [])
        if isinstance(audiences, str):
            audiences = [audiences]
        if claims.get("iss") != settings.jwt_issuer or settings.jwt_audience not in audiences:
            raise ValueError("Invalid token audience")
        return claims
    except (ValueError, TypeError, KeyError, AttributeError, OverflowError, json.JSONDecodeError, binascii.Error, UnicodeDecodeError):
        raise HTTPException(401, "A valid backend bearer token is required")


def require_role(actor: dict, *roles: str):
    role = actor.get("role") or actor.get("http://schemas.microsoft.com/ws/2008/06/identity/claims/role")
    if role not in roles:
        raise HTTPException(403, "This decision belongs to a different role")
