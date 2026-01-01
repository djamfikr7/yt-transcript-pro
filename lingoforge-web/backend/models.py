"""
LingoForge Studio - Database Models & Caching System
Enhanced version with 4-level caching as per specs502.md
"""

from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean, JSON, ForeignKey
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from datetime import datetime
import json
import os
import hashlib
from pathlib import Path

Base = declarative_base()

# Project Status Enum
class ProjectStatus:
    CREATED = "created"
    DOWNLOADING = "downloading"
    PROCESSING = "processing"
    TRANSCRIBING = "transcribing"
    TRANSLATING = "translating"
    DUBBING = "dubbing"
    COMPLETED = "completed"
    FAILED = "failed"
    RETRYING = "retrying"

class Project(Base):
    """Main project model"""
    __tablename__ = "projects"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(500))
    url = Column(String(1000))
    status = Column(String(50), default=ProjectStatus.CREATED)
    thumbnail_url = Column(String(1000), nullable=True)
    duration = Column(Float, nullable=True)
    audio_path = Column(String(1000), nullable=True)
    video_path = Column(String(1000), nullable=True)
    error_message = Column(Text, nullable=True)
    summary = Column(Text, nullable=True)
    key_points = Column(Text, nullable=True)
    social_content = Column(Text, nullable=True)
    blog_content = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Specs502 enhancements
    video_metadata = Column(JSON, default=dict)  # Store video metadata
    quality = Column(String(20), default="1080p")  # Video quality
    playlist_index = Column(Integer, nullable=True)  # For playlist items
    is_playlist = Column(Boolean, default=False)
    parent_project_id = Column(Integer, nullable=True)  # For playlist parent
    progress = Column(Integer, default=0)  # Progress percentage (0-100)
    playlist_id = Column(String(100), nullable=True, index=True) # Group ID for batch export
    playlist_title = Column(String(500), nullable=True) # Title of the playlist
    
    # Relationships
    transcripts = relationship("Transcript", back_populates="project", cascade="all, delete-orphan", foreign_keys="Transcript.project_id")
    translations = relationship("Translation", back_populates="project", cascade="all, delete-orphan", foreign_keys="Translation.project_id")
    clips = relationship("Clip", back_populates="project", cascade="all, delete-orphan", foreign_keys="Clip.project_id")
    
    def to_dict(self):
        return {
            "id": self.id,
            "title": self.title,
            "url": self.url,
            "status": self.status,
            "progress": self.progress,
            "thumbnail_url": self.thumbnail_url,
            "duration": self.duration,
            "audio_path": self.audio_path,
            "video_path": self.video_path,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "updated_at": self.updated_at.isoformat() if self.updated_at else None,
            "metadata": self.video_metadata,
            "quality": self.quality,
            "playlist_index": self.playlist_index,
            "is_playlist": self.is_playlist,
            "parent_project_id": self.parent_project_id,
            "playlist_id": self.playlist_id,
            "playlist_title": self.playlist_title,
            "error_message": self.error_message,
            "summary": self.summary,
            "key_points": self.key_points,
            "social_content": self.social_content,
            "blog_content": self.blog_content,
        }

class Transcript(Base):
    """Transcript model with enhanced features"""
    __tablename__ = "transcripts"
    
    id = Column(Integer, primary_key=True, index=True)
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=False, index=True)
    language = Column(String(10), default="en")
    segments = Column(Text, nullable=False)  # JSON string of segments
    speaker_diarization = Column(Text, nullable=True)  # JSON string of speaker segments
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Specs502 enhancements
    emotion_scores = Column(Text, nullable=True)  # JSON string of emotion data
    scene_markers = Column(Text, nullable=True)  # JSON string of scene data
    confidence_score = Column(Float, default=0.0)
    
    # Relationships
    project = relationship("Project", back_populates="transcripts", foreign_keys=[project_id])
    
    def get_segments(self):
        """Parse segments from JSON string"""
        try:
            return json.loads(self.segments) if self.segments else []
        except Exception as e:
            print(f"⚠️ Failed to parse segments JSON: {e}")
            return []
    
    def get_speakers(self):
        """Get unique speakers"""
        try:
            segments = self.get_segments()
            speakers = set(s.get('speaker', '') for s in segments if s.get('speaker'))
            return list(speakers)
        except Exception as e:
            print(f"⚠️ Failed to parse speakers JSON: {e}")
            return []

    def to_dict(self):
        return {
            "id": self.id,
            "project_id": self.project_id,
            "language": self.language,
            "segments": self.get_segments(),
            "speaker_diarization": self.speaker_diarization,
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "confidence_score": self.confidence_score,
            "emotion_scores": self.emotion_scores,
            "scene_markers": self.scene_markers
        }

class Translation(Base):
    """Translation model with memory"""
    __tablename__ = "translations"
    
    id = Column(Integer, primary_key=True, index=True)
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=False, index=True)
    source_language = Column(String(10), default="en")
    target_language = Column(String(10), nullable=False)
    segments = Column(Text, nullable=False)  # JSON string of translated segments
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Specs502 enhancements - Translation Memory
    translation_memory_key = Column(String(64), nullable=True)  # Hash for cache lookup
    adaptation_score = Column(Float, default=0.0)  # LLM adaptation quality
    
    # Relationships
    project = relationship("Project", back_populates="translations", foreign_keys=[project_id])
    
    def get_segments(self):
        """Parse translated segments"""
        try:
            return json.loads(self.segments) if self.segments else []
        except Exception as e:
            print(f"⚠️ Failed to parse translation segments JSON: {e}")
            return []

    def to_dict(self):
        return {
            "id": self.id,
            "project_id": self.project_id,
            "source_language": self.source_language,
            "target_language": self.target_language,
            "segments": self.get_segments(),
            "created_at": self.created_at.isoformat() if self.created_at else None,
            "adaptation_score": self.adaptation_score
        }

class Clip(Base):
    """Social media clip model"""
    __tablename__ = "clips"
    
    id = Column(Integer, primary_key=True, index=True)
    project_id = Column(Integer, ForeignKey("projects.id"), nullable=False, index=True)
    platform = Column(String(50), nullable=False)  # tiktok, youtube, etc.
    clip_path = Column(String(1000), nullable=False)
    duration = Column(Float, nullable=False)
    start_time = Column(Float, nullable=False)
    thumbnail_path = Column(String(1000), nullable=True)
    clip_metadata = Column(JSON, default=dict)  # Engagement predictions, best post time, etc.
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    project = relationship("Project", back_populates="clips", foreign_keys=[project_id])

    def to_dict(self):
        return {
            "id": self.id,
            "project_id": self.project_id,
            "platform": self.platform,
            "clip_path": self.clip_path,
            "duration": self.duration,
            "start_time": self.start_time,
            "thumbnail_path": self.thumbnail_path,
            "metadata": self.clip_metadata,
            "created_at": self.created_at.isoformat() if self.created_at else None
        }

class CacheEntry(Base):
    """4-Level Cache System - Level 4: Translation Memory"""
    __tablename__ = "cache_entries"
    
    id = Column(Integer, primary_key=True, index=True)
    cache_key = Column(String(64), unique=True, index=True)
    cache_level = Column(Integer, nullable=False)  # 1=RAM, 2=Disk, 3=Model, 4=TranslationMemory
    data_type = Column(String(50), nullable=False)  # transcript, translation, etc.
    data = Column(Text, nullable=False)  # JSON string
    size_bytes = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
    last_accessed = Column(DateTime, default=datetime.utcnow)
    ttl_seconds = Column(Integer, default=86400)  # 24 hours default
    
    def is_expired(self):
        """Check if cache entry is expired"""
        from datetime import datetime, timedelta
        if self.ttl_seconds is None:
            return False
        expiry_time = self.created_at + timedelta(seconds=self.ttl_seconds)
        return datetime.utcnow() > expiry_time

# Enhanced 4-Level Cache Manager
class LFSuperCache:
    """
    4-Level Cache System as specified in specs502.md:
    - L1: RAM (LRU, 2GB)
    - L2: Disk (SSD, 50GB)
    - L3: Model Cache (VRAM)
    - L4: Translation Memory (SQLite)
    """
    
    def __init__(self, db_session=None):
        self.l1_cache = {}  # In-memory LRU cache
        self.l1_max_size = 2 * 1024 * 1024 * 1024  # 2GB
        self.l1_current_size = 0
        
        self.l2_path = Path("/tmp/lingoforge/cache")
        self.l2_path.mkdir(parents=True, exist_ok=True)
        self.l2_max_size = 50 * 1024 * 1024 * 1024  # 50GB
        
        self.l3_cache = {}  # Model cache (VRAM)
        self.l3_max_size = 8  # Keep 8 models max
        
        self.db_session = db_session  # For L4 (Translation Memory)
        
    def _generate_key(self, data_type, input_data):
        """Generate unique cache key"""
        key_string = f"{data_type}:{str(input_data)}"
        return hashlib.sha256(key_string.encode()).hexdigest()
    
    def get(self, data_type, input_data):
        """Unified cache get with 4-level fallback"""
        cache_key = self._generate_key(data_type, input_data)
        
        # L1: RAM Cache
        if cache_key in self.l1_cache:
            entry = self.l1_cache[cache_key]
            entry['last_accessed'] = datetime.utcnow()
            return entry['data']
        
        # L2: Disk Cache
        disk_file = self.l2_path / f"{cache_key}.json"
        if disk_file.exists():
            try:
                with open(disk_file, 'r') as f:
                    data = json.load(f)
                # Promote to L1
                self._set_l1(cache_key, data)
                return data
            except Exception as e:
                print(f"⚠️ Failed to read L1 cache: {e}")
                pass
        
        # L3: Model Cache (handled by service layer)
        # L4: Translation Memory (SQLite)
        if self.db_session:
            try:
                entry = self.db_session.query(CacheEntry).filter_by(
                    cache_key=cache_key, cache_level=4
                ).first()
                if entry and not entry.is_expired():
                    data = json.loads(entry.data)
                    # Promote to L1
                    self._set_l1(cache_key, data)
                    # Update last accessed
                    entry.last_accessed = datetime.utcnow()
                    self.db_session.commit()
                    return data
            except Exception as e:
                print(f"⚠️ Failed to read L4 cache: {e}")
                pass
        
        return None
    
    def set(self, data_type, input_data, data, level=4, ttl_seconds=86400):
        """Set cache at specified level"""
        cache_key = self._generate_key(data_type, input_data)
        
        # L1: RAM
        if level >= 1:
            self._set_l1(cache_key, data, ttl_seconds)
        
        # L2: Disk
        if level >= 2:
            disk_file = self.l2_path / f"{cache_key}.json"
            try:
                with open(disk_file, 'w') as f:
                    json.dump(data, f)
            except Exception as e:
                print(f"⚠️ Failed to write L2 cache file {cache_file}: {e}")
                pass
        
        # L4: Translation Memory
        if level >= 4 and self.db_session:
            try:
                # Remove existing
                existing = self.db_session.query(CacheEntry).filter_by(cache_key=cache_key).first()
                if existing:
                    existing.data = json.dumps(data)
                    existing.last_accessed = datetime.utcnow()
                    existing.ttl_seconds = ttl_seconds
                else:
                    # Calculate size
                    size = len(json.dumps(data))
                    
                    # Create new entry
                    entry = CacheEntry(
                        cache_key=cache_key,
                        cache_level=4,
                        data_type=data_type,
                        data=json.dumps(data),
                        size_bytes=size,
                        ttl_seconds=ttl_seconds
                    )
                    self.db_session.add(entry)
                
                self.db_session.commit()
            except Exception as e:
                print(f"L4 Cache error: {e}")
                self.db_session.rollback()
    
    def _set_l1(self, cache_key, data, ttl_seconds=3600):
        """Set L1 cache with LRU eviction"""
        data_size = len(json.dumps(data))
        
        # Evict if needed
        while (self.l1_current_size + data_size > self.l1_max_size) and self.l1_cache:
            # Remove oldest
            oldest_key = min(self.l1_cache.keys(), 
                           key=lambda k: self.l1_cache[k]['last_accessed'])
            removed = self.l1_cache.pop(oldest_key)
            self.l1_current_size -= removed['size']
        
        self.l1_cache[cache_key] = {
            'data': data,
            'size': data_size,
            'last_accessed': datetime.utcnow(),
            'ttl_seconds': ttl_seconds
        }
        self.l1_current_size += data_size
    
    def clear_expired(self):
        """Clear expired entries from all levels"""
        # L1
        now = datetime.utcnow()
        to_remove = []
        for key, entry in self.l1_cache.items():
            if entry['ttl_seconds']:
                expiry = entry['last_accessed'] + timedelta(seconds=entry['ttl_seconds'])
                if now > expiry:
                    to_remove.append(key)
        for key in to_remove:
            removed = self.l1_cache.pop(key)
            self.l1_current_size -= removed['size']
        
        # L2
        for file in self.l2_path.glob("*.json"):
            try:
                file.unlink()
            except Exception as e:
                print(f"⚠️ Failed to delete cache file {file}: {e}")
                pass
        
        # L4
        if self.db_session:
            try:
                self.db_session.query(CacheEntry).filter(
                    CacheEntry.last_accessed < now - timedelta(seconds=86400)
                ).delete()
                self.db_session.commit()
            except Exception as e:
                print(f"⚠️ Failed to commit L4 cache: {e}")
                self.db_session.rollback()

# Hardware Detection
class HardwareSpecs:
    """Auto-detect hardware capabilities"""
    
    @staticmethod
    def detect():
        """Detect system hardware"""
        specs = {
            "cpu": {"cores": os.cpu_count() or 4},
            "gpu": {"vram": 0, "name": "None"},
            "ram": {"total": 0},
            "storage": {"free": 0}
        }
        
        # Try to detect GPU
        try:
            import subprocess
            # Check for NVIDIA GPU
            result = subprocess.run(['nvidia-smi', '--query-gpu=memory.total,name', '--format=csv,noheader,nounits'], 
                                  capture_output=True, text=True)
            if result.returncode == 0 and result.stdout:
                lines = result.stdout.strip().split('\n')
                if lines:
                    parts = lines[0].split(', ')
                    specs['gpu']['vram'] = int(parts[0])  # MB
                    specs['gpu']['name'] = parts[1] if len(parts) > 1 else "NVIDIA GPU"
        except Exception as e:
            print(f"⚠️ Failed to detect GPU: {e}")
            pass
        
        # RAM detection
        try:
            import psutil
            specs['ram']['total'] = psutil.virtual_memory().total // (1024**3)  # GB
            specs['storage']['free'] = psutil.disk_usage('/').free // (1024**3)  # GB
        except Exception as e:
            print(f"⚠️ Failed to detect storage: {e}")
            pass
        
        return specs
    
    @staticmethod
    def get_optimal_config(specs):
        """Get optimal configuration based on hardware"""
        gpu_vram_mb = specs['gpu']['vram']
        
        if gpu_vram_mb >= 24000:  # 24GB+
            return {
                "whisper_model": "large-v3",
                "parallel_jobs": 4,
                "enable_lip_sync": True,
                "cache_l1_size": 4 * 1024 * 1024 * 1024,  # 4GB
                "max_concurrent_downloads": 5
            }
        elif gpu_vram_mb >= 12000:  # 12GB+
            return {
                "whisper_model": "medium",
                "parallel_jobs": 2,
                "enable_lip_sync": False,
                "cache_l1_size": 2 * 1024 * 1024 * 1024,  # 2GB
                "max_concurrent_downloads": 3
            }
        elif gpu_vram_mb >= 6000:  # 6GB+
            return {
                "whisper_model": "small",
                "parallel_jobs": 1,
                "enable_lip_sync": False,
                "cache_l1_size": 1 * 1024 * 1024 * 1024,  # 1GB
                "max_concurrent_downloads": 2
            }
        else:
            return {
                "whisper_model": "tiny",
                "parallel_jobs": 1,
                "enable_lip_sync": False,
                "cache_l1_size": 512 * 1024 * 1024,  # 512MB
                "max_concurrent_downloads": 1
            }
