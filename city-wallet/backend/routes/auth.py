from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from passlib.context import CryptContext
from jose import jwt
from datetime import datetime, timedelta
from database import get_db
from config import settings
from services.stripe_service import create_express_account
from middleware.auth import get_current_user
from fastapi import Depends

router = APIRouter(prefix="/api/auth", tags=["auth"])
_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")


class RegisterIn(BaseModel):
    email: str
    password: str
    role: str  # 'consumer' | 'merchant'
    name: str = ""


class LoginIn(BaseModel):
    email: str
    password: str


class PushTokenIn(BaseModel):
    expo_push_token: str


def _make_token(user_id: int, role: str, email: str) -> str:
    payload = {
        "sub": str(user_id),
        "role": role,
        "email": email,
        "exp": datetime.utcnow() + timedelta(days=30),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


@router.post("/register")
async def register(body: RegisterIn):
    if body.role not in ("consumer", "merchant"):
        raise HTTPException(400, "role must be consumer or merchant")
    db = await get_db()

    async with db.execute("SELECT id FROM users WHERE email=?", (body.email,)) as cur:
        if await cur.fetchone():
            raise HTTPException(400, "Email already registered")

    stripe_account_id = ""
    if body.role == "consumer":
        stripe_account_id = await create_express_account(body.email)

    hashed = _pwd.hash(body.password)
    async with db.execute(
        "INSERT INTO users (email, password_hash, role, name, stripe_account_id) VALUES (?,?,?,?,?)",
        (body.email, hashed, body.role, body.name, stripe_account_id),
    ) as cur:
        user_id = cur.lastrowid

    if body.role == "merchant":
        await db.execute("INSERT INTO merchant_wallets (merchant_id) VALUES (?)", (user_id,))

    await db.commit()
    token = _make_token(user_id, body.role, body.email)
    return {"token": token, "role": body.role, "user_id": user_id, "name": body.name}


@router.post("/login")
async def login(body: LoginIn):
    db = await get_db()
    async with db.execute("SELECT * FROM users WHERE email=?", (body.email,)) as cur:
        user = await cur.fetchone()
    if not user or not _pwd.verify(body.password, user["password_hash"]):
        raise HTTPException(401, "Invalid credentials")
    token = _make_token(user["id"], user["role"], user["email"])
    return {"token": token, "role": user["role"], "user_id": user["id"], "name": user["name"]}


@router.get("/me")
async def me(user: dict = Depends(get_current_user)):
    db = await get_db()
    async with db.execute("SELECT id,email,role,name,stripe_account_id FROM users WHERE id=?", (int(user["sub"]),)) as cur:
        row = await cur.fetchone()
    if not row:
        raise HTTPException(404, "User not found")
    return dict(row)


@router.post("/push-token")
async def save_push_token(body: PushTokenIn, user: dict = Depends(get_current_user)):
    db = await get_db()
    await db.execute(
        "UPDATE users SET expo_push_token=? WHERE id=?",
        (body.expo_push_token, int(user["sub"])),
    )
    await db.commit()
    return {"saved": True}
