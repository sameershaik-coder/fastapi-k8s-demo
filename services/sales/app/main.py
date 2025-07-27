from fastapi import FastAPI, HTTPException, Depends
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from datetime import datetime
import os

# Database configuration
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost/sales_db")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database Models
class Sale(Base):
    __tablename__ = "sales"
    
    id = Column(Integer, primary_key=True, index=True)
    salesperson_name = Column(String, index=True)
    customer_name = Column(String, index=True)
    product_name = Column(String, index=True)
    quantity = Column(Integer)
    unit_price = Column(Float)
    total_amount = Column(Float)
    commission = Column(Float)
    sale_date = Column(DateTime, default=datetime.utcnow)

# Pydantic Models
class SaleCreate(BaseModel):
    salesperson_name: str
    customer_name: str
    product_name: str
    quantity: int
    unit_price: float
    commission_rate: float = 0.05  # 5% default commission

class SaleResponse(BaseModel):
    id: int
    salesperson_name: str
    customer_name: str
    product_name: str
    quantity: int
    unit_price: float
    total_amount: float
    commission: float
    sale_date: datetime

    class Config:
        from_attributes = True

# FastAPI App
app = FastAPI(title="Sales Service", version="1.0.0")

# Create tables
Base.metadata.create_all(bind=engine)

# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_root():
    return {"message": "Sales Service is running"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "sales"}

@app.post("/sales", response_model=SaleResponse)
def create_sale(sale: SaleCreate, db: Session = Depends(get_db)):
    total_amount = sale.quantity * sale.unit_price
    commission = total_amount * sale.commission_rate
    
    db_sale = Sale(
        salesperson_name=sale.salesperson_name,
        customer_name=sale.customer_name,
        product_name=sale.product_name,
        quantity=sale.quantity,
        unit_price=sale.unit_price,
        total_amount=total_amount,
        commission=commission
    )
    db.add(db_sale)
    db.commit()
    db.refresh(db_sale)
    return db_sale

@app.get("/sales", response_model=list[SaleResponse])
def get_sales(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    sales = db.query(Sale).offset(skip).limit(limit).all()
    return sales

@app.get("/sales/{sale_id}", response_model=SaleResponse)
def get_sale(sale_id: int, db: Session = Depends(get_db)):
    sale = db.query(Sale).filter(Sale.id == sale_id).first()
    if sale is None:
        raise HTTPException(status_code=404, detail="Sale not found")
    return sale

@app.get("/sales/salesperson/{salesperson_name}", response_model=list[SaleResponse])
def get_sales_by_salesperson(salesperson_name: str, db: Session = Depends(get_db)):
    sales = db.query(Sale).filter(Sale.salesperson_name == salesperson_name).all()
    return sales
