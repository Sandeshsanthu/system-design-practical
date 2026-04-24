import uuid, json, redis, os
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, String, Text, Integer, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session, relationship
from passlib.context import CryptContext
from jose import jwt

# --- Configurations ---
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@db:5432/mydatabase")
REDIS_HOST = os.getenv("REDIS_HOST", "cache")
REDIS_PORT = int(os.getenv("REDIS_PORT", 6379))
SECRET_KEY = "DEV_SECRET_KEY"  # In production, use a strong random secret
ALGORITHM = "HS256"

# --- Setup ---
redis_client = redis.Redis(host=REDIS_HOST, port=REDIS_PORT, db=0)
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")


# --- Models ---
class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    hashed_password = Column(String)
    jobs = relationship("JobModel", back_populates="owner")


class JobModel(Base):
    __tablename__ = "jobs"
    job_id = Column(String, primary_key=True, index=True)
    status = Column(String, default="pending")
    metadata_json = Column(Text)
    download_url = Column(Text, nullable=True)
    owner_id = Column(Integer, ForeignKey("users.id"))
    owner = relationship("User", back_populates="jobs")


Base.metadata.create_all(bind=engine)

app = FastAPI()


# --- Pydantic Schemas ---
class JobRequest(BaseModel):
    action: str
    params: dict


# --- Dependencies ---
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401, detail="Invalid token")
        user = db.query(User).filter(User.username == username).first()
        if not user:
            raise HTTPException(status_code=401, detail="User not found")
        return user
    except Exception:
        raise HTTPException(status_code=401, detail="Could not validate credentials")


# --- Authentication Routes ---

@app.get("/")
def read_root():
    return FileResponse("Frontend/index.html")


@app.post("/register")
def register(username: str, password: str, db: Session = Depends(get_db)):
    # Check if user exists
    if db.query(User).filter(User.username == username).first():
        raise HTTPException(status_code=400, detail="Username already registered")

    hashed_pw = pwd_context.hash(password)
    new_user = User(username=username, hashed_password=hashed_pw)
    db.add(new_user)
    db.commit()
    return {"message": "User created successfully"}


@app.post("/token")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == form_data.username).first()
    if not user or not pwd_context.verify(form_data.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect username or password")

    access_token = jwt.encode({"sub": user.username}, SECRET_KEY, algorithm=ALGORITHM)
    return {"access_token": access_token, "token_type": "bearer"}


# --- Job Routes ---

@app.post("/jobs", status_code=202)
def create_job(request: JobRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    job_id = str(uuid.uuid4())
    try:
        new_job = JobModel(
            job_id=job_id,
            status="pending",
            metadata_json=json.dumps(request.dict()),
            owner_id=current_user.id
        )
        db.add(new_job)
        db.commit()

        job_payload = {
            "job_id": job_id,
            "data": request.dict()
        }
        redis_client.rpush("job_queue", json.dumps(job_payload))
        return {"job_id": job_id, "status": "pending"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/jobs/{job_id}")
def get_status(job_id: str, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    # Filter by job_id AND owner_id so users can't see each other's jobs
    job = db.query(JobModel).filter(JobModel.job_id == job_id, JobModel.owner_id == current_user.id).first()

    if not job:
        raise HTTPException(status_code=404, detail="Job not found or access denied")

    return {
        "job_id": job.job_id,
        "status": job.status,
        "download_url": job.download_url
    }
