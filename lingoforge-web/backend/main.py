"""
LingoForge Studio - FastAPI Backend
Complete specs502 implementation
"""
from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import os
import asyncio
import json
from datetime import datetime
import traceback
from pathlib import Path
import uuid
import re


# Config
# Store data in a sibling directory to keep app folder clean
# ../lingoforge-web -> ../lingoforge_data
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR.parent / "lingoforge_data"
DATA_DIR.mkdir(exist_ok=True)

DOWNLOADS_DIR = DATA_DIR / "downloads"
CACHE_DIR = DATA_DIR / "cache"
DB_PATH = DATA_DIR / "lingoforge.db"

DOWNLOADS_DIR.mkdir(exist_ok=True)
CACHE_DIR.mkdir(exist_ok=True)

# Migrate old database if exists
import shutil
OLD_DB_PATH = BASE_DIR / "backend" / "lingoforge.db"
if not DB_PATH.exists() and OLD_DB_PATH.exists():
    try:
        shutil.copy2(OLD_DB_PATH, DB_PATH)
        print(f"📦 Migrated existing database to {DB_PATH}")
    except Exception as e:
        print(f"⚠️ Database migration warning: {e}")

# Import models and services
from models import (
    Base, Project, Transcript, Translation, Clip, CacheEntry,
    ProjectStatus, LFSuperCache, HardwareSpecs
)
from services.downloader import DownloaderService
from services.transcriber import TranscriberService
from services.translator import TranslatorService
from services.llm_service import LLMService
from services.tts_service import TTSService
from services.search_service import SearchService
from services.cache_service import CacheService
from services.clip_service import extract_clip, find_highlight_moments, create_social_clips

# Database setup
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session

# Request models
class CreateProjectRequest(BaseModel):
    url: str
    quality: Optional[str] = "best"
    is_playlist: Optional[bool] = False

class TranslateRequest(BaseModel):
    project_id: int
    target_lang: str

class LLMRequest(BaseModel):
    project_id: int
    operation: str
    platform: Optional[str] = "twitter"

class TTSRequest(BaseModel):
    project_id: int
    voice: Optional[str] = "en_female"

class SearchRequest(BaseModel):
    query: str
    method: Optional[str] = "keyword"

class ExportRequest(BaseModel):
    project_id: int
    format: str
    include_timestamps: Optional[bool] = True

class ClipRequest(BaseModel):
    project_id: int
    platform: str
    start_time: float
    duration: float

# Initialize app
app = FastAPI(
    title="LingoForge Studio API",
    description="Complete backend for YouTube transcription, translation, and dubbing",
    version="5.0.2"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global state
db_engine = None
SessionLocal = None
services = {}
cache_manager = None

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.on_event("startup")
async def startup_event():
    """Initialize database and services"""
    global db_engine, SessionLocal, services, cache_manager
    
    # Initialize database
    # Initialize database
    db_url = f"sqlite:///{DB_PATH}"
    db_engine = create_engine(db_url, connect_args={"check_same_thread": False})
    Base.metadata.create_all(db_engine)
    
    # Migration: Add columns if missing
    try:
        with db_engine.connect() as conn:
            # Check and add progress
            try:
                conn.execute(text("ALTER TABLE projects ADD COLUMN progress INTEGER DEFAULT 0"))
                print("✅ Added 'progress' column")
            except Exception: pass
            
            # Check and add playlist_id
            try:
                conn.execute(text("ALTER TABLE projects ADD COLUMN playlist_id VARCHAR(100)"))
                print("✅ Added 'playlist_id' column")
            except Exception: pass
            
            # Check and add playlist_title
            try:
                conn.execute(text("ALTER TABLE projects ADD COLUMN playlist_title VARCHAR(500)"))
                print("✅ Added 'playlist_title' column")
            except Exception: pass
            
            conn.commit()
    except Exception as e:
        print(f"⚠️ Migration warning: {e}")
    
    # Create session maker
    SessionLocal = sessionmaker(bind=db_engine, autocommit=False, autoflush=False)
    
    # Global semaphore to limit concurrent downloads
    # Initialize in startup as it requires event loop in some environments, or just global
    global download_semaphore
    download_semaphore = asyncio.Semaphore(2)

    # Initialize cache manager
    
    # Initialize cache manager
    cache_manager = LFSuperCache(SessionLocal())
    
    # Detect hardware
    hardware_specs = HardwareSpecs.detect()
    optimal_config = HardwareSpecs.get_optimal_config(hardware_specs)
    
    print(f"🔧 Hardware: {hardware_specs['gpu']['name']}")
    print(f"⚙️  Config: {optimal_config['whisper_model']}")
    
    # Initialize services
    # Initialize services with new paths
    services = {
        'downloader': DownloaderService(str(DOWNLOADS_DIR)),
        'transcriber': TranscriberService(),
        'translator': TranslatorService(cache_manager=cache_manager),
        'llm': LLMService(),
        'tts': TTSService(str(CACHE_DIR)),
        'search': SearchService(),
        'cache': CacheService() # Update if it uses cache dir
    }
    
    # Resume stuck downloads on startup
    try:
        db = SessionLocal()
        stuck_projects = db.query(Project).filter(Project.status.in_([ProjectStatus.DOWNLOADING, ProjectStatus.CREATED])).all()
        if stuck_projects:
            print(f"🔄 Found {len(stuck_projects)} interrupted downloads. Resuming...")
            for p in stuck_projects:
                asyncio.create_task(process_project_task(p.id, p.url, p.quality or 'best'))
                print(f"   Resuming project #{p.id}: {p.url}")
        db.close()
    except Exception as e:
        print(f"⚠️ Startup recovery error: {e}")
    
    print("✅ LingoForge Studio backend started successfully")

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "services": list(services.keys()),
        "version": "5.0.2"
    }

async def process_project_task(project_id: int, url: str, quality: str):
    """Background processing task"""
    # Use semaphore to limit network/cpu usage
    # Use semaphore to limit network/cpu usage
    await download_semaphore.acquire()
    
    db = SessionLocal()
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        if not project:
            print(f"❌ Project {project_id} not found in database.")
            return
        
        print(f"🚀 Starting background task for Project {project_id}")
        print(f"🔗 URL: {url}")
        print(f"🎞️ Quality: {quality}")
        
        # Helper for progress
        def update_pb(percent: int, status_msg: str = None):
            try:
                _db = SessionLocal()
                p = _db.query(Project).get(project_id)
                if p:
                    p.progress = percent
                    if status_msg:
                        if status_msg == 'retrying':
                            p.status = ProjectStatus.RETRYING
                        elif status_msg == 'downloading':
                            p.status = ProjectStatus.DOWNLOADING
                    _db.commit()
                _db.close()
            except Exception:
                pass
        
        # Download
        project.status = ProjectStatus.DOWNLOADING
        project.progress = 0
        db.commit()
        
        downloader = services['downloader']
        download_result = await downloader.download_video(url, str(project_id), progress_callback=update_pb)
        
        if not download_result['success']:
            print(f"❌ Download failed for project {project_id}: {download_result.get('error')}")
            project.status = ProjectStatus.FAILED
            project.error_message = f"Download failed: {download_result.get('error')}"
            db.commit()
            return
        
        print(f"✅ Downloaded: {download_result['title']} ({download_result['duration']}s)")
        
        project.video_path = download_result['video_path']
        project.title = download_result['title']
        project.duration = download_result['duration']
        project.thumbnail_url = download_result.get('thumbnail')
        project.status = ProjectStatus.PROCESSING
        db.commit()
        
        # Transcribe
        project.status = ProjectStatus.TRANSCRIBING
        project.progress = 0
        db.commit()
        
        transcriber = services['transcriber']
        transcribe_result = await transcriber.transcribe(
            download_result['video_path'], 
            str(project_id)
        )
        
        if not transcribe_result['success']:
            project.status = ProjectStatus.FAILED
            db.commit()
            return
        
        # Save transcript
        transcript = Transcript(
            project_id=project_id,
            language=transcribe_result.get('language', 'en'),
            segments=json.dumps(transcribe_result.get('segments', [])),
            confidence_score=transcribe_result.get('confidence', 0.0)
        )
        db.add(transcript)
        db.commit()
        
        # Generate LLM content
        llm = services['llm']
        transcript_text = " ".join([s.get('text', '') for s in transcribe_result.get('segments', [])])
        
        # Summary
        summary_result = await llm.summarize(transcript_text, "concise")
        if summary_result['success']:
            project.summary = summary_result['summary']
        
        # Key points
        key_points_result = await llm.extract_key_points(transcript_text, 5)
        if key_points_result['success']:
            project.key_points = json.dumps(key_points_result['key_points'])
        
        # Social content
        social_result = await llm.generate_social_content(transcript_text, "twitter")
        if social_result['success']:
            project.social_content = social_result['content']
        
        # Blog content
        blog_result = await llm.generate_blog_post(transcript_text)
        if blog_result['success']:
            project.blog_content = blog_result['blog_post']
        
        project.status = ProjectStatus.COMPLETED
        db.commit()
        
    except Exception as e:
        error_msg = str(e)
        print(f"Error processing project {project_id}: {error_msg}")
        try:
            # Re-query project in case simple usage fails
            project = db.query(Project).filter(Project.id == project_id).first()
            if project:
                project.status = ProjectStatus.FAILED
                project.error_message = error_msg
                db.commit()
        except:
            pass
    finally:
        db.close()
        download_semaphore.release()

@app.post("/projects")
async def create_project(request: CreateProjectRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)):
    """Create new project"""
    try:
        # Check for playlist
        if request.is_playlist or (request.url and ('list=' in request.url or 'playlist' in request.url)):
            print(f"📂 Detected playlist: {request.url}")
            playlist_info = await services['downloader'].get_playlist_info(request.url)
            
            if playlist_info['success'] and playlist_info['videos']:
                print(f"   Found {len(playlist_info['videos'])} videos in playlist")
                created_projects = []
                import uuid
                playlist_id = f"PL-{str(uuid.uuid4())[:8]}"
                playlist_title = playlist_info.get('title', 'Playlist')
                
                # Limit playlist items to prevent instant overload if necessary (e.g. max 50)
                # For now allow all
                for video in playlist_info['videos']:
                    project = Project(
                        url=video['url'],
                        title=video['title'],
                        quality=request.quality,
                        is_playlist=True,
                        playlist_id=playlist_id,
                        playlist_title=playlist_title,
                        status=ProjectStatus.CREATED
                    )
                    db.add(project)
                    db.commit()
                    db.refresh(project)
                    
                    background_tasks.add_task(process_project_task, project.id, video['url'], request.quality)
                    created_projects.append(project)
                
                return {
                    "success": True,
                    "message": f"Started processing {len(created_projects)} videos from playlist",
                    "project_id": created_projects[0].id if created_projects else None,
                    "playlist_id": playlist_id,
                    "batch_count": len(created_projects)
                }

        # Single video flow
        project = Project(
            url=request.url,
            quality=request.quality,
            is_playlist=request.is_playlist,
            status=ProjectStatus.CREATED
        )
        
        db.add(project)
        db.commit()
        db.refresh(project)
        
        # Start background processing
        background_tasks.add_task(process_project_task, project.id, project.url, project.quality)
        
        return {
            "success": True,
            "project_id": project.id,
            "title": project.title,
            "status": project.status
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects")
async def list_projects(db: Session = Depends(get_db)):
    try:
        projects = db.query(Project).all()
        return {
            "success": True,
            "projects": [p.to_dict() for p in projects],
            "total": len(projects)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects/{project_id}")
async def get_project(project_id: int, db: Session = Depends(get_db)):
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        transcripts = db.query(Transcript).filter(Transcript.project_id == project_id).all()
        translations = db.query(Translation).filter(Translation.project_id == project_id).all()
        clips = db.query(Clip).filter(Clip.project_id == project_id).all()
        
        result = project.to_dict()
        result['transcripts'] = [t.to_dict() for t in transcripts]
        result['translations'] = [t.to_dict() for t in translations]
        result['clips'] = [c.to_dict() for c in clips]
        
        return {"success": True, "project": result}
    except Exception as e:
        # Log the error for debugging
        print(f"Error in get_project: {str(e)}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/projects/{project_id}")
async def delete_project(project_id: int, db: Session = Depends(get_db)):
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        # Clean up files
        for attr in ['video_path', 'audio_path']:
            path = getattr(project, attr)
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except:
                    pass
        
        # Delete associated records
        db.query(Transcript).filter(Transcript.project_id == project_id).delete()
        db.query(Translation).filter(Translation.project_id == project_id).delete()
        db.query(Clip).filter(Clip.project_id == project_id).delete()
        
        db.delete(project)
        db.commit()
        
        return {"success": True, "message": "Project deleted"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/languages")
async def get_languages():
    """Get available translation languages"""
    translator = services.get('translator')
    if translator:
        result = await translator.get_available_languages()
        if result.get('success'):
            # Convert language codes to objects with code and name
            lang_codes = result.get('languages', [])
            language_names = {
                'en': 'English', 'es': 'Spanish', 'fr': 'French',
                'de': 'German', 'it': 'Italian', 'pt': 'Portuguese',
                'ru': 'Russian', 'ja': 'Japanese', 'ko': 'Korean',
                'zh': 'Chinese', 'ar': 'Arabic'
            }
            languages = [
                {"code": code, "name": language_names.get(code, code.upper())}
                for code in lang_codes
            ]
            return {
                "success": True,
                "languages": languages,
                "source": result.get("source", "argostranslate")
            }
    return {
        "success": True,
        "languages": [
            {"code": "en", "name": "English"},
            {"code": "fr", "name": "French"},
            {"code": "ar", "name": "Arabic"},
            {"code": "es", "name": "Spanish"},
            {"code": "de", "name": "German"},
            {"code": "it", "name": "Italian"},
            {"code": "pt", "name": "Portuguese"},
            {"code": "ru", "name": "Russian"},
            {"code": "ja", "name": "Japanese"},
            {"code": "ko", "name": "Korean"},
            {"code": "zh", "name": "Chinese"}
        ],
        "source": "default"
    }

@app.post("/projects/{project_id}/translate")
async def translate_project(project_id: int, target_lang: str = "fr", source_lang: str = "auto", db: Session = Depends(get_db)):
    """Translate a project's transcript to target language"""
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        transcript = db.query(Transcript).filter(Transcript.project_id == project_id).first()
        if not transcript:
            raise HTTPException(status_code=400, detail="No transcript available for this project")
        
        # Get transcript text
        segments = json.loads(transcript.segments)
        full_text = " ".join([s.get('text', '') for s in segments])
        
        if not full_text.strip():
            raise HTTPException(status_code=400, detail="Transcript is empty")
        
        # Translate
        project.status = ProjectStatus.TRANSLATING
        project.progress = 10
        db.commit()
        
        translator = services['translator']
        result = await translator.translate_text(full_text, target_lang, source_lang if source_lang != "auto" else transcript.language)

        project.progress = 100
        project.status = ProjectStatus.COMPLETED
        db.commit()
        
        if result['success']:
            # Save translation to database
            translation = Translation(
                project_id=project_id,
                source_language=result.get('source_lang', transcript.language),
                target_language=result.get('target_lang', target_lang),
                segments=json.dumps([{
                    "text": result['translated_text'],
                    "original": full_text
                }])
            )
            db.add(translation)
            db.commit()
            
            return {
                "success": True,
                "translation_id": translation.id,
                "translated_text": result['translated_text'],
                "source_lang": result.get('source_lang', transcript.language),
                "target_lang": result.get('target_lang', target_lang)
            }
        else:
            raise HTTPException(status_code=500, detail=result.get('error', 'Translation failed'))
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/projects/{project_id}/tts")
async def generate_project_tts(project_id: int, voice: str = "en_female", db: Session = Depends(get_db)):
    """Generate TTS audio for a project"""
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        # Get text - prefer translation, fallback to transcript
        text = None
        translation = db.query(Translation).filter(Translation.project_id == project_id).first()
        if translation:
            segments = json.loads(translation.segments)
            text = " ".join([s.get('text', '') for s in segments])
        
        if not text:
            transcript = db.query(Transcript).filter(Transcript.project_id == project_id).first()
            if transcript:
                segments = json.loads(transcript.segments)
                text = " ".join([s.get('text', '') for s in segments])
        
        if not text or not text.strip():
            raise HTTPException(status_code=400, detail="No text available for TTS")
        
        # Limit text size for TTS (edge-tts can struggle with very long texts)
        # Approximately 5000 chars = ~3-4 minutes of speech
        # Determine text length for logging but don't arbitrarily truncate
        # We will handle chunking in the service
        original_length = len(text)
        print(f"🎤 Generating TTS for project {project_id} ({original_length} chars)")
        
        # Generate TTS
        tts = services['tts']
        result = await tts.generate_speech(text, voice)
        
        if result['success']:
            return {
                "success": True,
                "filepath": result['filepath'],
                "filename": result['filename'],
                "file_size": result['file_size'],
                "voice": voice,
                "download_url": f"/tts/download/{result['filename']}",
                "original_chars": original_length,
                "processed_chars": len(text)
            }
        else:
            raise HTTPException(status_code=500, detail=result.get('error', 'TTS generation failed'))
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/voices")
async def get_voices():
    """Get available TTS voices"""
    tts = services.get('tts')
    if tts:
        result = await tts.get_available_voices()
        if result.get('success'):
            return result
    return {
        "success": True,
        "voices": [
            {"id": "en_female", "name": "English Female", "language": "en"},
            {"id": "en_male", "name": "English Male", "language": "en"},
            {"id": "fr_female", "name": "French Female", "language": "fr"},
            {"id": "fr_male", "name": "French Male", "language": "fr"},
            {"id": "ar_female", "name": "Arabic Female", "language": "ar"},
            {"id": "ar_male", "name": "Arabic Male", "language": "ar"},
            {"id": "es_female", "name": "Spanish Female", "language": "es"},
            {"id": "es_male", "name": "Spanish Male", "language": "es"},
            {"id": "de_female", "name": "German Female", "language": "de"},
            {"id": "de_male", "name": "German Male", "language": "de"},
            {"id": "it_female", "name": "Italian Female", "language": "it"},
            {"id": "it_male", "name": "Italian Male", "language": "it"},
            {"id": "pt_female", "name": "Portuguese Female", "language": "pt"},
            {"id": "pt_male", "name": "Portuguese Male", "language": "pt"},
            {"id": "ru_female", "name": "Russian Female", "language": "ru"},
            {"id": "ru_male", "name": "Russian Male", "language": "ru"},
            {"id": "ja_female", "name": "Japanese Female", "language": "ja"},
            {"id": "ja_male", "name": "Japanese Male", "language": "ja"},
            {"id": "ko_female", "name": "Korean Female", "language": "ko"},
            {"id": "ko_male", "name": "Korean Male", "language": "ko"},
            {"id": "zh_female", "name": "Chinese Female", "language": "zh"},
            {"id": "zh_male", "name": "Chinese Male", "language": "zh"}
        ],
        "source": "default"
    }

@app.post("/translate")
async def translate(request: TranslateRequest, db: Session = Depends(get_db)):
    try:
        project = db.query(Project).filter(Project.id == request.project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        transcript = db.query(Transcript).filter(Transcript.project_id == request.project_id).first()
        if not transcript:
            raise HTTPException(status_code=400, detail="No transcript available")
        
        # Check cache
        cache_key = f"translation:{request.project_id}:{request.target_lang}"
        cached = cache_manager.get("translation", cache_key)
        if cached:
            return {
                "success": True,
                "translated_text": cached,
                "source_lang": transcript.language,
                "target_lang": request.target_lang,
                "cached": True
            }
        
        # Translate
        translator = services['translator']
        segments = json.loads(transcript.segments)
        full_text = " ".join([s.get('text', '') for s in segments])
        
        result = await translator.translate_text(
            full_text,
            request.target_lang,
            transcript.language
        )
        
        if result['success']:
            translation = Translation(
                project_id=request.project_id,
                source_language=transcript.language,
                target_language=request.target_lang,
                segments=json.dumps([{
                    "text": result['translated_text'],
                    "original": full_text
                }])
            )
            db.add(translation)
            db.commit()
            
            cache_manager.set("translation", cache_key, result['translated_text'], level=4)
            
            return {
                "success": True,
                "translated_text": result['translated_text'],
                "source_lang": transcript.language,
                "target_lang": request.target_lang,
                "cached": False
            }
        else:
            raise HTTPException(status_code=500, detail=result['error'])
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/llm")
async def llm_operation(request: LLMRequest, db: Session = Depends(get_db)):
    try:
        project = db.query(Project).filter(Project.id == request.project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        transcript = db.query(Transcript).filter(Transcript.project_id == request.project_id).first()
        if not transcript:
            raise HTTPException(status_code=400, detail="No transcript available")
        
        segments = json.loads(transcript.segments)
        transcript_text = " ".join([s.get('text', '') for s in segments])
        
        llm = services['llm']
        
        if request.operation == "summarize":
            result = await llm.summarize(transcript_text, "concise")
            if result['success']:
                project.summary = result['summary']
                db.commit()
                return {"success": True, "summary": result['summary']}
                
        elif request.operation == "key_points":
            result = await llm.extract_key_points(transcript_text, 5)
            if result['success']:
                project.key_points = json.dumps(result['key_points'])
                db.commit()
                return {"success": True, "key_points": result['key_points']}
                
        elif request.operation == "social":
            result = await llm.generate_social_content(transcript_text, request.platform or "twitter")
            if result['success']:
                project.social_content = result['content']
                db.commit()
                return {"success": True, "content": result['content']}
                
        elif request.operation == "blog":
            result = await llm.generate_blog_post(transcript_text)
            if result['success']:
                project.blog_content = result['blog_post']
                db.commit()
                return {"success": True, "blog_post": result['blog_post']}
        
        raise HTTPException(status_code=500, detail="LLM operation failed")
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/tts")
async def text_to_speech(request: TTSRequest, db: Session = Depends(get_db)):
    try:
        project = db.query(Project).filter(Project.id == request.project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        # Get text
        text = None
        translation = db.query(Translation).filter(Translation.project_id == request.project_id).first()
        if translation:
            segments = json.loads(translation.segments)
            text = " ".join([s.get('text', '') for s in segments])
        
        if not text:
            transcript = db.query(Transcript).filter(Transcript.project_id == request.project_id).first()
            if transcript:
                segments = json.loads(transcript.segments)
                text = " ".join([s.get('text', '') for s in segments])
        
        if not text:
            raise HTTPException(status_code=400, detail="No text available")
        
        # Check cache
        cache_key = f"tts:{request.project_id}:{request.voice}"
        cached = cache_manager.get("tts", cache_key)
        if cached and os.path.exists(cached):
            return {
                "success": True,
                "filepath": cached,
                "filename": os.path.basename(cached),
                "file_size": os.path.getsize(cached),
                "duration": 0,
                "cached": True
            }
        
        # Generate speech
        tts = services['tts']
        result = await tts.generate_speech(text, request.voice)
        
        if result['success']:
            cache_manager.set("tts", cache_key, result['filepath'], level=2)
            return {
                "success": True,
                "filepath": result['filepath'],
                "filename": result['filename'],
                "file_size": result['file_size'],
                "duration": result['duration'],
                "cached": False
            }
        else:
            raise HTTPException(status_code=500, detail=result['error'])
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/tts/download/{filename}")
async def download_tts(filename: str):
    try:
        filepath = os.path.join("./cache", filename)
        if not os.path.exists(filepath):
            raise HTTPException(status_code=404, detail="File not found")
        return FileResponse(filepath, media_type="audio/mpeg", filename=filename)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/search")
async def search(query: str, method: str = "keyword", db: Session = Depends(get_db)):
    try:
        projects = db.query(Project).all()
        
        if not projects:
            return {"success": True, "results": [], "total": 0}
        
        # Prepare data
        project_data = []
        for p in projects:
            transcript = db.query(Transcript).filter(Transcript.project_id == p.id).first()
            data = p.to_dict()
            if transcript:
                data['transcript_text'] = " ".join([s.get('text', '') for s in json.loads(transcript.segments)])
            project_data.append(data)
        
        search_service = services['search']
        
        if method == "semantic":
            result = await search_service.semantic_search(query, project_data)
        else:
            result = await search_service.search_projects(query, project_data)
        
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects/{project_id}/export")
async def export_project(project_id: int, format: str = "txt", include_timestamps: bool = True, db: Session = Depends(get_db)):
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        # Get content
        content = None
        translation = db.query(Translation).filter(Translation.project_id == project_id).first()
        if translation:
            segments = json.loads(translation.segments)
            content = " ".join([s.get('text', '') for s in segments])
        
        if not content:
            transcript = db.query(Transcript).filter(Transcript.project_id == project_id).first()
            if transcript:
                segments = json.loads(transcript.segments)
                content = " ".join([s.get('text', '') for s in segments])
        
        if not content:
            # Fallback message instead of error
            content = "[No speech content detected or processed for this project. This might happen if the video has no speech or transcription failed.]"
            include_timestamps = False # No timestamps for placeholder
        
        # Generate export
        export_content = ""
        
        # Use video title for filename (sanitized)
        safe_title = project.title or f"project_{project.id}"
        # Remove or replace unsafe characters, limit length
        safe_title = re.sub(r'[^\w\s-]', '', safe_title)  # Keep only word chars, spaces, hyphens
        safe_title = re.sub(r'\s+', '_', safe_title.strip())  # Replace spaces with underscores
        safe_title = safe_title[:50]  # Limit to 50 chars
        filename = f"{safe_title}.{format}"
        
        # Save to local disk as fallback
        try:
            local_filepath = DOWNLOADS_DIR / filename
            with open(local_filepath, "w") as f:
                f.write(export_content)
            print(f"💾 Saved export to: {local_filepath}")
        except Exception as e:
            print(f"⚠️ Failed to save local export copy: {e}")

        if format == "txt":
            export_content = content
        elif format == "srt":
            transcript = db.query(Transcript).filter(Transcript.project_id == project_id).first()
            if transcript and include_timestamps:
                segments = json.loads(transcript.segments)
                export_content = ""
                for i, seg in enumerate(segments):
                    start = seg.get('start', 0)
                    end = seg.get('end', start + 1)
                    text = seg.get('text', '')
                    export_content += f"{i+1}\n{format_timestamp(start)} --> {format_timestamp(end)}\n{text}\n\n"
            else:
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if line.strip():
                        export_content += f"{i+1}\n00:00:00,000 --> 00:00:01,000\n{line.strip()}.\n\n"
        elif format == "vtt":
            export_content = "WEBVTT\n\n"
            transcript = db.query(Transcript).filter(Transcript.project_id == project_id).first()
            if transcript and include_timestamps:
                segments = json.loads(transcript.segments)
                for i, seg in enumerate(segments):
                    start = seg.get('start', 0)
                    end = seg.get('end', start + 1)
                    text = seg.get('text', '')
                    export_content += f"{i+1}\n{format_timestamp(start, vtt=True)} --> {format_timestamp(end, vtt=True)}\n{text}\n\n"
            else:
                lines = content.split('.')
                for i, line in enumerate(lines):
                    if line.strip():
                        export_content += f"{i+1}\n00:00:00.000 --> 00:00:01.000\n{line.strip()}.\n\n"
        
        import tempfile
        temp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, suffix=f".{format}")
        temp_file.write(export_content)
        temp_file.close()

        # Physical fallback copy for user
        try:
            local_export_path = DOWNLOADS_DIR / filename
            with open(local_export_path, "w") as f:
                f.write(export_content)
            print(f"💾 Physical export saved to: {local_export_path}")
        except Exception as e:
            print(f"⚠️ Failed to save physical export: {e}")
        
        return {
            "success": True,
            "content": export_content,
            "filename": filename,
            "download_url": f"/export/download/{os.path.basename(temp_file.name)}",
            "local_path": str(local_export_path)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/export/download/{filename}")
async def download_export(filename: str):
    try:
        import tempfile
        temp_dir = tempfile.gettempdir()
        filepath = os.path.join(temp_dir, filename)
        
        if not os.path.exists(filepath):
            raise HTTPException(status_code=404, detail="File not found")
        
        return FileResponse(filepath, media_type="text/plain", filename=filename)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects/batch/{playlist_id}/export")
async def export_batch(playlist_id: str, db: Session = Depends(get_db)):
    """Export all completed projects in a batch as a single file"""
    try:
        projects = db.query(Project).filter(
            Project.playlist_id == playlist_id,
            Project.status == ProjectStatus.COMPLETED
        ).order_by(Project.id.asc()).all()
        
        if not projects:
            raise HTTPException(status_code=404, detail="No completed projects found in this batch")
            
        combined_text = ""
        playlist_title = projects[0].playlist_title or "Playlist"
        
        combined_text += f"BATCH EXPORT: {playlist_title}\n"
        combined_text += f"Playlist ID: {playlist_id}\n"
        combined_text += f"Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
        combined_text += "="*60 + "\n\n"
        
        for i, p in enumerate(projects, 1):
            combined_text += f"[{i}/{len(projects)}] VIDEO: {p.title}\n"
            combined_text += f"URL: {p.url}\n"
            combined_text += "-"*30 + "\n"
            
            content = None
            translation = db.query(Translation).filter(Translation.project_id == p.id).first()
            if translation:
                segments = json.loads(translation.segments)
                content = "\n".join([s.get('text', '') for s in segments])
                combined_text += f"(Source: Translation)\n"
            else:
                transcript = db.query(Transcript).filter(Transcript.project_id == p.id).first()
                if transcript:
                    segments = json.loads(transcript.segments)
                    content = "\n".join([s.get('text', '') for s in segments])
                    combined_text += f"(Source: Original Transcript)\n"
            
            if content:
                combined_text += content
            else:
                combined_text += "[No content found]"
            
            combined_text += "\n\n" + "#"*60 + "\n\n"
            
        safe_title = re.sub(r'[^\w\s-]', '', playlist_title)
        safe_title = re.sub(r'\s+', '_', safe_title.strip())[:40]
        filename = f"batch_{safe_title}_{playlist_id[:8]}.txt"
        
        # Save to physical downloads folder
        local_path = DOWNLOADS_DIR / filename
        with open(local_path, "w") as f:
            f.write(combined_text)
            
        return {
            "success": True,
            "content": combined_text,
            "filename": filename,
            "count": len(projects),
            "local_path": str(local_path)
        }
    except Exception as e:
        print(f"Batch export error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/clips")
async def create_clip(request: ClipRequest, db: Session = Depends(get_db)):
    """Create a clip from a project using FFmpeg"""
    try:
        project = db.query(Project).filter(Project.id == request.project_id).first()
        
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        if not project.video_path or not os.path.exists(project.video_path):
            raise HTTPException(status_code=400, detail="Video not available")
        
        # Determine aspect ratio based on platform
        aspect_ratio_map = {
            "tiktok": "9:16",
            "reels": "9:16",
            "shorts": "9:16",
            "instagram": "1:1",
            "youtube": "16:9",
            "twitter": "16:9"
        }
        aspect_ratio = aspect_ratio_map.get(request.platform.lower(), "16:9")
        
        # Generate output path
        clip_filename = f"clip_{request.project_id}_{request.platform}_{int(request.start_time)}.mp4"
        clip_path = os.path.join(str(CACHE_DIR), clip_filename)
        
        # Extract clip using FFmpeg
        result_path = extract_clip(
            video_path=project.video_path,
            output_path=clip_path,
            start_time=request.start_time,
            duration=request.duration,
            aspect_ratio=aspect_ratio
        )
        
        if not result_path or not os.path.exists(result_path):
            raise HTTPException(status_code=500, detail="Failed to extract clip using FFmpeg")
        
        # Save clip record to database
        clip = Clip(
            project_id=request.project_id,
            platform=request.platform,
            clip_path=result_path,
            duration=request.duration,
            start_time=request.start_time,
            clip_metadata={
                "aspect_ratio": aspect_ratio,
                "engagement_score": 0.85,
                "best_post_time": "18:00",
                "hashtags": ["#YouTube", "#Transcription", f"#{request.platform}"]
            }
        )
        
        db.add(clip)
        db.commit()
        db.refresh(clip)
        
        return {
            "success": True,
            "clip_id": clip.id,
            "clip_path": result_path,
            "download_url": f"/clips/download/{clip_filename}",
            "duration": request.duration,
            "platform": request.platform,
            "aspect_ratio": aspect_ratio,
            "file_size_mb": round(os.path.getsize(result_path) / (1024 * 1024), 2)
        }
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/clips/download/{filename}")
async def download_clip(filename: str):
    """Download a generated clip"""
    try:
        filepath = os.path.join(str(CACHE_DIR), filename)
        if not os.path.exists(filepath):
            raise HTTPException(status_code=404, detail="Clip file not found")
        return FileResponse(filepath, media_type="video/mp4", filename=filename)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/cache/stats")
async def cache_stats(db: Session = Depends(get_db)):
    try:
        cache = LFSuperCache(db)
        
        l1_count = len(cache.l1_cache)
        l1_size = cache.l1_current_size
        
        l2_files = list(cache.l2_path.glob("*.json")) if cache.l2_path.exists() else []
        l2_count = len(l2_files)
        l2_size = sum(f.stat().st_size for f in l2_files)
        
        l4_count = db.query(CacheEntry).count()
        l4_size = sum(e.size_bytes for e in db.query(CacheEntry).all())
        
        return {
            "success": True,
            "l1": {"entries": l1_count, "size_bytes": l1_size},
            "l2": {"entries": l2_count, "size_bytes": l2_size},
            "l4": {"entries": l4_count, "size_bytes": l4_size},
            "total": {"entries": l1_count + l2_count + l4_count, "size_bytes": l1_size + l2_size + l4_size}
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/cache/clear")
async def clear_cache(db: Session = Depends(get_db)):
    try:
        cache = LFSuperCache(db)
        
        cache.l1_cache.clear()
        cache.l1_current_size = 0
        
        if cache.l2_path.exists():
            for f in cache.l2_path.glob("*.json"):
                f.unlink()
        
        db.query(CacheEntry).delete()
        db.commit()
        
        return {"success": True, "message": "Cache cleared"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/hardware")
async def hardware_info():
    try:
        specs = HardwareSpecs.detect()
        config = HardwareSpecs.get_optimal_config(specs)
        return {
            "success": True,
            "specs": specs,
            "optimal_config": config
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# =====================
# FILE MANAGER ENDPOINTS
# =====================

@app.get("/files")
async def list_files():
    """List all files in downloads and cache directories with sizes"""
    try:
        files = []
        
        # List downloads
        downloads_dir = "./downloads"
        if os.path.exists(downloads_dir):
            for f in os.listdir(downloads_dir):
                filepath = os.path.join(downloads_dir, f)
                if os.path.isfile(filepath):
                    files.append({
                        "name": f,
                        "path": filepath,
                        "directory": "downloads",
                        "size_bytes": os.path.getsize(filepath),
                        "size_mb": round(os.path.getsize(filepath) / (1024 * 1024), 2),
                        "modified": os.path.getmtime(filepath)
                    })
        
        # List cache
        cache_dir = "./cache"
        if os.path.exists(cache_dir):
            for f in os.listdir(cache_dir):
                filepath = os.path.join(cache_dir, f)
                if os.path.isfile(filepath):
                    files.append({
                        "name": f,
                        "path": filepath,
                        "directory": "cache",
                        "size_bytes": os.path.getsize(filepath),
                        "size_mb": round(os.path.getsize(filepath) / (1024 * 1024), 2),
                        "modified": os.path.getmtime(filepath)
                    })
        
        # Calculate totals
        total_size = sum(f["size_bytes"] for f in files)
        
        return {
            "success": True,
            "files": files,
            "total_files": len(files),
            "total_size_mb": round(total_size / (1024 * 1024), 2),
            "total_size_gb": round(total_size / (1024 * 1024 * 1024), 2)
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/files/{directory}/{filename}")
async def delete_file(directory: str, filename: str):
    """Delete a specific file from downloads or cache"""
    try:
        if directory not in ["downloads", "cache"]:
            raise HTTPException(status_code=400, detail="Invalid directory. Use 'downloads' or 'cache'")
        
        filepath = os.path.join(f"./{directory}", filename)
        
        if not os.path.exists(filepath):
            raise HTTPException(status_code=404, detail="File not found")
        
        # Security check - prevent path traversal
        if ".." in filename or "/" in filename:
            raise HTTPException(status_code=400, detail="Invalid filename")
        
        os.remove(filepath)
        
        return {
            "success": True,
            "message": f"Deleted {filename} from {directory}"
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/files/cleanup")
async def cleanup_all_files():
    """Delete all files from downloads and cache directories"""
    try:
        deleted_count = 0
        freed_bytes = 0
        
        for directory in ["./downloads", "./cache"]:
            if os.path.exists(directory):
                for f in os.listdir(directory):
                    filepath = os.path.join(directory, f)
                    if os.path.isfile(filepath):
                        freed_bytes += os.path.getsize(filepath)
                        os.remove(filepath)
                        deleted_count += 1
        
        return {
            "success": True,
            "deleted_files": deleted_count,
            "freed_mb": round(freed_bytes / (1024 * 1024), 2),
            "message": f"Cleaned up {deleted_count} files, freed {round(freed_bytes / (1024 * 1024), 2)} MB"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects/{project_id}/translations")
async def get_project_translations(project_id: int, db: Session = Depends(get_db)):
    """Get all translations for a project"""
    try:
        translations = db.query(Translation).filter(Translation.project_id == project_id).all()
        return {
            "success": True,
            "translations": [t.to_dict() for t in translations]
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/projects/{project_id}/translation/export")
async def export_translation(project_id: int, format: str = "txt", db: Session = Depends(get_db)):
    """Export translation as file"""
    try:
        project = db.query(Project).filter(Project.id == project_id).first()
        if not project:
            raise HTTPException(status_code=404, detail="Project not found")
        
        translation = db.query(Translation).filter(Translation.project_id == project_id).order_by(Translation.id.desc()).first()
        if not translation:
            raise HTTPException(status_code=404, detail="No translation found for this project")
        
        segments = json.loads(translation.segments)
        content = " ".join([s.get('text', '') for s in segments])
        
        # Generate filename with video title and language
        import re
        safe_title = project.title or f"project_{project.id}"
        safe_title = re.sub(r'[^\w\s-]', '', safe_title)
        safe_title = re.sub(r'\s+', '_', safe_title.strip())[:40]
        filename = f"{safe_title}_{translation.target_language}.{format}"
        
        return {
            "success": True,
            "content": content,
            "filename": filename,
            "source_lang": translation.source_language,
            "target_lang": translation.target_language
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def format_timestamp(seconds, vtt=False):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    ms = int((seconds % 1) * 1000)
    
    if vtt:
        return f"{hours:02d}:{minutes:02d}:{secs:02d}.{ms:03d}"
    else:
        return f"{hours:02d}:{minutes:02d}:{secs:02d},{ms:03d}"

# =====================
# SERVE FRONTEND (SPA)
# =====================

# Mount assets folder explicitly for performance
if os.path.exists("../frontend/dist/assets"):
    app.mount("/assets", StaticFiles(directory="../frontend/dist/assets"), name="assets")

@app.get("/{full_path:path}")
async def serve_spa(full_path: str):
    """Serve the React frontend"""
    # 1. Check if it's a file in dist (e.g. favicon.ico)
    dist_file = os.path.join("../frontend/dist", full_path)
    if os.path.isfile(dist_file):
        return FileResponse(dist_file)
    
    # 2. Otherwise serve index.html (SPA routing)
    index_file = "../frontend/dist/index.html"
    if os.path.exists(index_file):
        return FileResponse(index_file)
        
    return {"message": "Frontend not found. Please run 'npm run build' in frontend directory."}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
