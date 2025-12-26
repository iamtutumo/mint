from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import pkgutil, importlib
import app.models as models_pkg

from app.db.base import Base
from app.models.product import Product, ProductType
from app.services.inventory import InventoryService


def setup_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    # import all models to ensure mappers configured
    for loader, name, ispkg in pkgutil.iter_modules(models_pkg.__path__):
        importlib.import_module(f"app.models.{name}")
    return Session()


def test_inventory_flow():
    db = setup_db()

    # create a physical product
    p = Product(name="Widget", product_type=ProductType.PHYSICAL, selling_price=10.0, stock_quantity=0)
    db.add(p)
    db.commit()
    db.refresh(p)

    # Purchase 10 units
    m1 = InventoryService.record_purchase(db, p.id, 10, 2.5, performed_by="tester")
    assert m1.quantity == 10
    assert InventoryService.get_current_stock(db, p.id) == 10

    # Sale 3 units
    m2 = InventoryService.record_sale(db, p.id, 3, performed_by="tester")
    assert InventoryService.get_current_stock(db, p.id) == 7

    # Adjustment -5 units (e.g., damage)
    m3 = InventoryService.adjust_inventory(db, p.id, -5, performed_by="tester", notes="damage")
    assert InventoryService.get_current_stock(db, p.id) == 2

    # Attempt to oversell should raise
    try:
        InventoryService.record_sale(db, p.id, 10, performed_by="tester")
        assert False, "Expected ValueError for insufficient stock"
    except ValueError:
        pass


if __name__ == "__main__":
    test_inventory_flow()
    print("inventory service tests passed")
