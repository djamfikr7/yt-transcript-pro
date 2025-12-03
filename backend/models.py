from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Float, Enum
from sqlalchemy.orm import declarative_base, relationship
from datetime import datetime
import enum

Base = declarative_base()

class ProjectStatus(str, enum.Enum):
    CREATED = "created"
    DOWNLOADING = "downloading"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"

class Project(Base):
    __tablename__ = "projects"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, index=True)
    url = Column(String)
    thumbnail_url = Column(String, nullable=True)
    duration = Column(Float, nullable=True) # in seconds
    status = Column(String, default=ProjectStatus.CREATED)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Paths to local files
    audio_path = Column(String, nullable=True)
    video_path = Column(String, nullable=True)
    
    transcripts = relationship("Transcript", back_populates="project", cascade="all, delete-orphan")

class Transcript(Base):
    __tablename__ = "transcripts"

    id = Column(Integer, primary_key=True, index=True)
    project_id = Column(Integer, ForeignKey("projects.id"))
    language = Column(String, default="en")
    content = Column(Text) # JSON stored as text or raw text
    created_at = Column(DateTime, default=datetime.utcnow)
    
    project = relationship("Project", back_populates="transcripts")
