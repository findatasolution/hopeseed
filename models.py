# models.py
from sqlalchemy import Column, Integer, String, Text, TIMESTAMP
from sqlalchemy.sql import func
from database import Base

class User(Base):
    __tablename__ = "users"  # bảng duy nhất hệ thống dùng
    user_id       = Column(Integer, primary_key=True, index=True)
    email         = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(Text, nullable=False)
    phone         = Column(String(50), nullable=True)
    created_at    = Column(TIMESTAMP, server_default=func.now(), nullable=False)
