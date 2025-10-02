import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv

# Load variables from a local .env if present
load_dotenv()

# Require DATABASE_URL (Railway/Neon); allow env override but default to original Neon connection
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL is not set. Configure your Neon connection string in the environment.") else {}

engine = create_engine(
    DATABASE_URL,
    echo=os.getenv("SQLALCHEMY_ECHO", "false").lower() == "true",
    pool_pre_ping=True,
    pool_recycle=1800,
    pool_size=int(os.getenv("SQLALCHEMY_POOL_SIZE", "5")),
    max_overflow=int(os.getenv("SQLALCHEMY_MAX_OVERFLOW", "10")),
    connect_args=connect_args
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
