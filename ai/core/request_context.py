from contextvars import ContextVar, Token
from typing import Optional


_authorization_header: ContextVar[Optional[str]] = ContextVar(
    "authorization_header",
    default=None,
)


def set_authorization_header(value: Optional[str]) -> Token:
    """Keep the calling worker's bearer token scoped to one AI workflow."""
    return _authorization_header.set(value)


def reset_authorization_header(token: Token) -> None:
    _authorization_header.reset(token)


def inventory_api_headers() -> dict[str, str]:
    authorization = _authorization_header.get()
    return {"Authorization": authorization} if authorization else {}
