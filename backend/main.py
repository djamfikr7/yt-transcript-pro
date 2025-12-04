from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import List, Optional
import threading
import asyncio
import logging
import traceback

from database import init_db, get_db, AsyncSessionLocal
from models import Project, Transcript, ProjectStatus
from services.downloader import download_audio
from services.transcriber import transcriber

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("backend_debug.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = FastAPI(title="YT Transcript Pro API")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic Models
class ProjectCreate(BaseModel):
    url: str

class ProjectResponse(BaseModel):
    id: int
    title: Optional[str]
    url: str
    status: str
    thumbnail_url: Optional[str]
    
    class Config:
        from_attributes = True

# Background Processing
def process_project_thread(project_id: int):
    """Run async processing in a new event loop (thread-safe)"""
    logger.info(f"[THREAD] Started for project {project_id}")
    try:
        asyncio.run(process_project_async(project_id))
    except Exception as e:
        logger.error(f"[THREAD] Error: {e}")
        logger.error(traceback.format_exc())

async def process_project_async(project_id: int):
    """Main processing logic"""
    logger.info(f"[BG] Processing project {project_id}")
    
    async with AsyncSessionLocal() as db:
        try:
            # Update status to downloading
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            if not project:
                logger.error(f"[BG] Project {project_id} not found!")
                return
                
            project.status = ProjectStatus.DOWNLOADING
            await db.commit()
            logger.info(f"[BG] Downloading {project.url}...")
            
            # Download
            metadata = await download_audio(project.url, project_id)
            logger.info(f"[BG] Downloaded: {metadata.get('title')}")
            
            # Update with metadata
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            project.title = metadata.get("title")
            project.duration = metadata.get("duration")
            project.thumbnail_url = metadata.get("thumbnail")
            project.audio_path = metadata.get("file_path")
            project.status = ProjectStatus.PROCESSING
            await db.commit()
            
            #  Transcribe
            logger.info(f"[BG] Transcribing {project.audio_path}...")
            transcript_result = await transcriber.transcribe(project.audio_path)
            logger.info(f"[BG] Transcribed {len(transcript_result['segments'])} segments")
            
            # Save transcript
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            
            new_transcript = Transcript(
                project_id=project.id,
                language=transcript_result["language"],
                content=str(transcript_result["segments"])
            )
            db.add(new_transcript)
            project.status = ProjectStatus.COMPLETED
            await db.commit()
            
            logger.info(f"[BG] ✅ Project {project_id} COMPLETED!")
            
        except Exception as e:
            logger.error(f"[BG] ❌ Error processing project {project_id}: {e}")
            logger.error(traceback.format_exc())
            
            # Try to update status to FAILED
            try:
                result = await db.execute(select(Project).where(Project.id == project_id))
                project = result.scalar_one_or_none()
                if project:
                    project.status = ProjectStatus.FAILED
                    await db.commit()
            except Exception as db_e:
                logger.error(f"[BG] Failed to update status to FAILED: {db_e}")

@app.on_event("startup")
async def on_startup():
    await init_db()

@app.get("/health")
def health_check():
    return {"status": "ok", "version": "0.1.0"}

@app.post("/projects", response_model=ProjectResponse)
async def create_project(
    project_in: ProjectCreate, 
    db: AsyncSession = Depends(get_db)
):
    new_project = Project(url=project_in.url, status=ProjectStatus.CREATED)
    db.add(new_project)
    await db.commit()
    await db.refresh(new_project)
    
    logger.info(f"[API] Created project {new_project.id}, starting thread...")
    thread = threading.Thread(target=process_project_thread, args=(new_project.id,))
    thread.daemon = True
    thread.start()
    
    return new_project

@app.get("/projects", response_model=List[ProjectResponse])
async def list_projects(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).order_by(Project.created_at.desc()))
    projects = result.scalars().all()
    return projects

@app.get("/projects/{project_id}")
async def get_project(project_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return project

@app.get("/projects/{project_id}/transcript")
async def get_transcript(project_id: int, db: AsyncSession = Depends(get_db)):
    """Get transcript segments for a project"""
    result = await db.execute(
        select(Transcript).where(Transcript.project_id == project_id)
    )
    transcripts = result.scalars().all()
    
    if not transcripts:
        raise HTTPException(status_code=404, detail="No transcript found")
    
    transcript = transcripts[-1]
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        segments = []
    
    return {
        "id": transcript.id,
        "language": transcript.language,
        "segments": segments,
        "created_at": transcript.created_at
    }
