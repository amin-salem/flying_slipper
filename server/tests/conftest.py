import os
import tempfile

# Settings must be set before the app is imported.
_tmp = tempfile.mkdtemp()
os.environ.update({
    "ENV": "dev",
    "DATABASE_URL": f"sqlite+aiosqlite:///{_tmp}/test.db",
    "BAZAAR_MODE": "fake",
    "RATE_LIMIT": "false",
    "ADMIN_API_KEY": "test-admin-key",
    "JWT_SECRET": "test-secret-that-is-long-enough-123456",
})

import httpx  # noqa: E402
import pytest  # noqa: E402

from app import db  # noqa: E402
from app.main import app  # noqa: E402

ADMIN = {"X-Admin-Key": "test-admin-key"}


@pytest.fixture(scope="session", autouse=True)
async def _tables():
    await db.create_tables()
    yield
    await db.engine.dispose()


@pytest.fixture
async def client():
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


async def new_player(client, device="device-1234"):
    r = await client.post("/v1/auth/register", json={"device_id": device, "app_version": 12})
    assert r.status_code == 200, r.text
    body = r.json()
    body["headers"] = {"Authorization": f"Bearer {body['token']}"}
    return body


def pytest_collection_modifyitems(items):
    """Run every async test in the same event loop as the database fixture."""
    session_loop = pytest.mark.asyncio(loop_scope="session")
    for item in items:
        if item.get_closest_marker("asyncio") is None and hasattr(item, "obj") and \
                __import__("inspect").iscoroutinefunction(item.obj):
            item.add_marker(session_loop)
