# main.py
import os
from fastapi import FastAPI, Depends, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy.orm import Session
from typing import Optional

from database import get_db, Base, engine
from models import User
from auth import hash_password, verify_password, create_access_token, decode_access_token

app = FastAPI(title="Auth-only API")

# Tự tạo bảng nếu muốn (set env AUTO_CREATE_TABLES=1)
if os.getenv("AUTO_CREATE_TABLES") == "1":
    Base.metadata.create_all(bind=engine)

# CORS
_cors_env = os.getenv("CORS_ALLOW_ORIGINS") or os.getenv("NETLIFY_URL") or "*"
allow_origins = [o.strip() for o in _cors_env.split(",")] if _cors_env else ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ======= Schemas =======
class UserCreate(BaseModel):
    email: EmailStr
    password: str

class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    phone: Optional[str] = None  # <- dùng string

class MeOut(BaseModel):
    email: EmailStr
    is_admin: bool

# ======= Helpers =======
def decode_token(token: str):
    try:
        return decode_access_token(token)
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

def get_current_user(authorization: str = Header(..., alias="Authorization"),
                     db: Session = Depends(get_db)) -> User:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    token = authorization.split(" ", 1)[1]
    payload = decode_token(token)
    email = payload.get("sub")
    if not email:
        raise HTTPException(status_code=401, detail="Invalid token payload")
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="User not found")
    return user

# ======= Endpoints =======
@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "API OK"}

@app.post("/register")
def register(user: UserRegister, db: Session = Depends(get_db)):
    email_lower = user.email.lower()
    exists = db.query(User).filter(User.email == user.email).first()
    if exists:
        raise HTTPException(status_code=400, detail="Email already registered")

    new_user = User(
        email=user.email,
        password_hash=hash_password(user.password),
        phone=user.phone
    )
    db.add(new_user)
    db.commit()
    return {"message": "User created", "is_admin": email_lower.startswith("admin@")}

@app.post("/login")
def login(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if not db_user or not verify_password(user.password, db_user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    is_admin = db_user.email.lower().startswith("admin@")
    claims = {"sub": db_user.email}
    if is_admin:
        claims["adm"] = True
    token = create_access_token(claims)

    return {
        "message": "Login successful",
        "email": db_user.email,
        "is_admin": is_admin,
        "access_token": token
    }

@app.get("/me", response_model=MeOut)
def me(current_user: User = Depends(get_current_user)):
    return MeOut(email=current_user.email, is_admin=current_user.email.lower().startswith("admin@"))
