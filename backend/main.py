from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import List, Optional
import asyncio

from database import init_db, get_db
from models import Project, Transcript, ProjectStatus
from services.downloader import download_audio
from services.transcriber import transcriber

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

# Background Task
async def process_project(project_id: int, db: AsyncSession):
    """
    Orchestrates the download and transcription process.
    """
    print(f"Starting processing for project {project_id}")
    
    # 1. Get Project
    async with db.begin(): # Transaction
        result = await db.execute(select(Project).where(Project.id == project_id))
        project = result.scalar_one_or_none()
        if not project:
            return
        project.status = ProjectStatus.DOWNLOADING
        await db.commit()

    try:
        # 2. Download
        print(f"Downloading {project.url}...")
        # Re-fetch project to avoid detached instance issues if needed, 
        # but for simple updates we might be ok. 
        # Ideally we pass IDs or manage session carefully.
        
        metadata = await download_audio(project.url, project_id)
        
        async with db.begin():
            # Re-fetch to update
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            project.title = metadata.get("title")
            project.duration = metadata.get("duration")
            project.thumbnail_url = metadata.get("thumbnail")
            project.audio_path = metadata.get("file_path")
            project.status = ProjectStatus.PROCESSING
            await db.commit()
            
        # 3. Transcribe
        print(f"Transcribing {project.audio_path}...")
        transcript_result = await transcriber.transcribe(project.audio_path)
        
        async with db.begin():
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            
            # Save Transcript
            new_transcript = Transcript(
                project_id=project.id,
                language=transcript_result["language"],
                content=str(transcript_result["segments"]) # Store as stringified JSON for now
            )
            db.add(new_transcript)
            
            project.status = ProjectStatus.COMPLETED
            await db.commit()
            
        print(f"Project {project_id} completed.")

    except Exception as e:
        print(f"Error processing project {project_id}: {e}")
        async with db.begin():
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            project.status = ProjectStatus.FAILED
            await db.commit()

@app.on_event("startup")
async def on_startup():
    await init_db()

@app.get("/health")
def health_check():
    return {"status": "ok", "version": "0.1.0"}

@app.post("/projects", response_model=ProjectResponse)
async def create_project(
    project_in: ProjectCreate, 
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    new_project = Project(url=project_in.url, status=ProjectStatus.CREATED)
    db.add(new_project)
    await db.commit()
    await db.refresh(new_project)
    
    # Start background processing
    # Note: We need a new session for the background task to avoid concurrency issues
    # For simplicity here, we're passing the logic to a function that should handle its own session
    # But `process_project` currently takes `db`. 
    # Better pattern: Pass ID and let background task create its own session.
    # Let's fix `process_project` to create its own session.
    
    background_tasks.add_task(run_process_project_safe, new_project.id)
    
    return new_project

async def run_process_project_safe(project_id: int):
    """Wrapper to create a new session for the background task"""
    from database import AsyncSessionLocal
    async with AsyncSessionLocal() as session:
        await process_project(project_id, session)

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
