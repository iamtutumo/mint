from fastapi import APIRouter
import logging

api_router = APIRouter()
logger = logging.getLogger("mercury")

# Helper to safely import and include routers from modules that may not exist
def _safe_include(module_name: str, router_name: str = "router", prefix: str | None = None, tags: list | None = None) -> bool:
    try:
        mod = __import__(module_name, fromlist=[router_name])
        router = getattr(mod, router_name)
        if prefix:
            api_router.include_router(router, prefix=prefix, tags=tags or [])
        else:
            api_router.include_router(router, tags=tags or [])
        logger.info(f"Included router from {module_name}")
        return True
    except Exception as e:
        logger.error(f"Could not include router from {module_name}: {e}")
        import traceback
        logger.error(traceback.format_exc())
        return False

# v1 routers (preferred location)
_safe_include("api.v1.products", prefix="/v1", tags=["products"])
_safe_include("api.v1.orders", prefix="/v1", tags=["orders"])

# Some routers live under app.api.v1 (booking, auth)
_safe_include("app.api.v1.bookings", prefix="/v1", tags=["bookings"])
_safe_include("app.api.v1.auth", prefix="/v1", tags=["auth"])

# Top-level api webhooks
_safe_include("api.api_webhooks", prefix="/v1", tags=["webhooks"])

# If a router could not be imported (missing or failing import),
# add a placeholder router so the path appears in the OpenAPI docs.
from fastapi import APIRouter

_missing = []
for name, tag in (
    ("bookings", "bookings"),
    ("inventory", "inventory"),
    ("payments", "payments"),
    ("documents", "documents"),
    ("accounts", "accounts"),
    ("transactions", "transactions"),
    ("reports", "reports"),
    ("auth", "auth"),
    ("mcp", "mcp")
):
    # Try various possible module locations
    imported = False
    for module_try in (f"app.api.v1.{name}", f"api.v1.{name}", f"api.{name}"):
        if _safe_include(module_try):
            imported = True
            break
    if not imported:
        # Add a non-breaking placeholder router so the path shows up in docs
        r = APIRouter(prefix=f"/v1/{name}", tags=[tag])

        @r.get("/", summary=f"{name} - placeholder")
        async def _placeholder_list():
            return {"status": "unavailable", "module": name}

        api_router.include_router(r)
        _missing.append(name)

if _missing:
    logger.warning(f"Some modules are missing; placeholder routers added for: {_missing}")






