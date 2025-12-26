from fastapi import FastAPI, Depends
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import pkgutil, importlib
import app.models as models_pkg
from app.db.base import Base
from app.models.product import Product, ProductType
from app.api.v1 import inventory as inventory_router_module

from app.api.v1.inventory import router as inventory_router


def setup_app_and_db():
    # setup in-memory DB
    engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
    Session = sessionmaker(bind=engine)
    # import all models first so metadata is registered
    for loader, name, ispkg in pkgutil.iter_modules(models_pkg.__path__):
        importlib.import_module(f"app.models.{name}")
    Base.metadata.create_all(engine)

    db = Session()

    # create a test product
    p = Product(name="API Widget", product_type=ProductType.PHYSICAL, selling_price=5.0, stock_quantity=0)
    db.add(p)
    db.commit()
    db.refresh(p)

    app = FastAPI()
    app.include_router(inventory_router)

    # override dependencies
    def _get_db_override():
        try:
            yield db
        finally:
            pass

    class FakeUser:
        def __init__(self, id=1, is_superuser=True):
            self.id = id
            self.is_superuser = is_superuser

    app.dependency_overrides[inventory_router_module.get_db] = _get_db_override
    app.dependency_overrides[inventory_router_module.get_current_user] = lambda: FakeUser()

    client = TestClient(app)
    return client, db, p


def test_api_purchase_and_stock():
    client, db, product = setup_app_and_db()

    # Purchase 5 units
    resp = client.post("/inventory/movements/purchase", json={"product_id": product.id, "quantity": 5, "unit_cost": 1.0})
    assert resp.status_code == 201
    data = resp.json()
    assert data["quantity"] == 5 or data.get("quantity") == 5

    # Check stock
    resp = client.get(f"/inventory/products/{product.id}/stock")
    assert resp.status_code == 200
    data = resp.json()
    assert data["stock_quantity"] == 5

    # Sale 2 units
    resp = client.post("/inventory/movements/sale", json={"product_id": product.id, "quantity": 2})
    assert resp.status_code == 200
    resp = client.get(f"/inventory/products/{product.id}/stock")
    assert resp.json()["stock_quantity"] == 3

    # Oversell should fail
    resp = client.post("/inventory/movements/sale", json={"product_id": product.id, "quantity": 10})
    assert resp.status_code == 400

    # Adjustment requires superuser - we provided one in override
    resp = client.post("/inventory/movements/adjust", json={"product_id": product.id, "adjustment": -1, "notes": "test adj"})
    assert resp.status_code == 200
    assert client.get(f"/inventory/products/{product.id}/stock").json()["stock_quantity"] == 2


if __name__ == "__main__":
    test_api_purchase_and_stock()
    print("inventory api tests passed")
