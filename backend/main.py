from fastapi import FastAPI, HTTPException, Depends, Response, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel
from typing import List, Optional
import threading
import asyncio
import logging
import traceback
import os
import shutil
import uuid

from database import init_db, get_db, AsyncSessionLocal
from models import Project, Transcript, ProjectStatus
from services.downloader import download_audio
from services.transcriber import transcriber
from services import exporter, translator
from services.diarizer import diarize_audio, merge_segments_with_speakers

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
    logger.info(f"[THREAD] Started for project {project_id}")
    try:
        asyncio.run(process_project_async(project_id))
    except Exception as e:
        logger.error(f"[THREAD] Error: {e}")
        logger.error(traceback.format_exc())

async def process_project_async(project_id: int):
    logger.info(f"[BG] Processing project {project_id}")
    
    async with AsyncSessionLocal() as db:
        try:
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            if not project:
                logger.error(f"[BG] Project {project_id} not found!")
                return
                
            project.status = ProjectStatus.DOWNLOADING
            await db.commit()
            logger.info(f"[BG] Downloading {project.url}...")
            
            metadata = await download_audio(project.url, project_id)
            logger.info(f"[BG] Downloaded: {metadata.get('title')}")
            
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            project.title = metadata.get("title")
            project.duration = metadata.get("duration")
            project.thumbnail_url = metadata.get("thumbnail")
            project.audio_path = metadata.get("file_path")
            project.status = ProjectStatus.PROCESSING
            await db.commit()
            
            logger.info(f"[BG] Transcribing {project.audio_path}...")
            transcript_result = await transcriber.transcribe(project.audio_path)
            logger.info(f"[BG] Transcribed {len(transcript_result['segments'])} segments")
            
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
    return {"status": "ok", "version": "0.2.0"}

@app.post("/projects", response_model=ProjectResponse)
async def create_project(project_in: ProjectCreate, db: AsyncSession = Depends(get_db)):
    new_project = Project(url=project_in.url, status=ProjectStatus.CREATED)
    db.add(new_project)
    await db.commit()
    await db.refresh(new_project)
    
    logger.info(f"[API] Created project {new_project.id}, starting thread...")
    thread = threading.Thread(target=process_project_thread, args=(new_project.id,))
    thread.daemon = True
    thread.start()
    
    return new_project

@app.post("/projects/upload")
async def upload_local_file(file: UploadFile = File(...), db: AsyncSession = Depends(get_db)):
    """Upload a local audio/video file for transcription."""
    # Validate file extension
    allowed_extensions = ['.mp4', '.mkv', '.mp3', '.wav', '.webm', '.m4a', '.ogg']
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(status_code=400, detail=f"Invalid file type. Allowed: {allowed_extensions}")
    
    # Create project
    new_project = Project(url=f"local://{file.filename}", status=ProjectStatus.CREATED, title=file.filename)
    db.add(new_project)
    await db.commit()
    await db.refresh(new_project)
    
    # Save file to disk
    project_dir = f"downloads/{new_project.id}"
    os.makedirs(project_dir, exist_ok=True)
    file_path = os.path.join(project_dir, f"audio{file_ext}")
    
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)
    
    logger.info(f"[API] Saved uploaded file to {file_path}")
    
    # Update project with file path
    result = await db.execute(select(Project).where(Project.id == new_project.id))
    project = result.scalar_one()
    project.audio_path = file_path
    project.status = ProjectStatus.PROCESSING
    await db.commit()
    
    # Start transcription in background
    def process_upload(proj_id: int, audio_path: str):
        asyncio.run(_process_uploaded_file(proj_id, audio_path))
    
    thread = threading.Thread(target=process_upload, args=(new_project.id, file_path))
    thread.daemon = True
    thread.start()
    
    return {"id": new_project.id, "status": "processing", "message": "File uploaded, transcription started"}

async def _process_uploaded_file(project_id: int, audio_path: str):
    """Process an uploaded file (transcribe only, no download needed)."""
    async with AsyncSessionLocal() as db:
        try:
            logger.info(f"[UPLOAD] Transcribing {audio_path}...")
            transcript_result = await transcriber.transcribe(audio_path)
            logger.info(f"[UPLOAD] Transcribed {len(transcript_result['segments'])} segments")
            
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            if not project:
                return
            
            new_transcript = Transcript(
                project_id=project.id,
                language=transcript_result["language"],
                content=str(transcript_result["segments"])
            )
            db.add(new_transcript)
            project.status = ProjectStatus.COMPLETED
            await db.commit()
            
            logger.info(f"[UPLOAD] ✅ Project {project_id} COMPLETED!")
        except Exception as e:
            logger.error(f"[UPLOAD] ❌ Error: {e}")
            result = await db.execute(select(Project).where(Project.id == project_id))
            project = result.scalar_one_or_none()
            if project:
                project.status = ProjectStatus.FAILED
                await db.commit()

@app.post("/projects/{project_id}/diarize")
async def run_diarization(project_id: int, db: AsyncSession = Depends(get_db)):
    """Run speaker diarization on a project's audio and update transcript with speaker labels."""
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    if not project.audio_path or not os.path.exists(project.audio_path):
        raise HTTPException(status_code=400, detail="No audio file available for diarization")
    
    # Get existing transcript
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalar_one_or_none()
    if not transcript:
        raise HTTPException(status_code=400, detail="No transcript found. Transcribe first.")
    
    # Run diarization
    logger.info(f"[API] Running diarization on project {project_id}...")
    speaker_segments = diarize_audio(project.audio_path)
    
    if not speaker_segments:
        return {"message": "Diarization unavailable or no speakers detected", "speakers": 0}
    
    # Parse existing transcript segments
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        segments = []
    
    # Merge with speaker labels
    merged_segments = merge_segments_with_speakers(segments, speaker_segments)
    
    # Update transcript
    transcript.content = str(merged_segments)
    await db.commit()
    
    num_speakers = len(set(s.get('speaker', '') for s in merged_segments if s.get('speaker')))
    logger.info(f"[API] Diarization complete: {num_speakers} speakers identified")
    
    return {"message": "Diarization complete", "speakers": num_speakers, "segments_updated": len(merged_segments)}

@app.get("/projects", response_model=List[ProjectResponse])
async def list_projects(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).order_by(Project.created_at.desc()))
    return result.scalars().all()

@app.get("/projects/{project_id}")
async def get_project(project_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    return project

@app.delete("/projects/{project_id}")
async def delete_project(project_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # Delete associated transcripts first
    from sqlalchemy import delete as sql_delete
    await db.execute(sql_delete(Transcript).where(Transcript.project_id == project_id))
    await db.delete(project)
    await db.commit()
    
    # Clean up any associated files
    import shutil
    project_dir = f"downloads/{project_id}"
    if os.path.exists(project_dir):
        try:
            shutil.rmtree(project_dir)
        except Exception as e:
            logger.warning(f"Failed to delete project files: {e}")
    
    return {"message": "Project deleted successfully"}

@app.get("/projects/{project_id}/transcript")
async def get_transcript(project_id: int, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
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

@app.get("/projects/{project_id}/export")
async def export_transcript(project_id: int, format: str = "txt", db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalars().first()
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        segments = []
    
    if format == "srt":
        content = exporter.to_srt(segments)
        filename = f"transcript_{project_id}.srt"
    elif format == "vtt":
        content = exporter.to_vtt(segments)
        filename = f"transcript_{project_id}.vtt"
    else:
        content = exporter.to_txt(segments)
        filename = f"transcript_{project_id}.txt"
        
    return Response(
        content=content,
        media_type="text/plain",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
    )


@app.post("/projects/{project_id}/translate")
async def translate_project(project_id: int, target_lang: str = "es", db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalars().first()
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        segments = []
    
    loop = asyncio.get_event_loop()
    translated = await loop.run_in_executor(None, translator.translate_segments, segments, target_lang)
    
    return {
        "original_language": transcript.language,
        "target_language": target_lang,
        "segments": translated
    }

# ========== LLM Content Repurposing Endpoints ==========

@app.post("/projects/{project_id}/summarize")
async def summarize_project(project_id: int, style: str = "concise", db: AsyncSession = Depends(get_db)):
    """Generate AI summary of the transcript"""
    from services import llm_service
    
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalars().first()
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        raise HTTPException(status_code=500, detail="Failed to parse transcript")
    
    return await llm_service.summarize(segments, style)

@app.post("/projects/{project_id}/key-points")
async def extract_key_points(project_id: int, count: int = 5, db: AsyncSession = Depends(get_db)):
    """Extract key points from the transcript"""
    from services import llm_service
    
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalars().first()
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        raise HTTPException(status_code=500, detail="Failed to parse transcript")
    
    return await llm_service.extract_key_points(segments, count)

@app.post("/projects/{project_id}/social-content")
async def generate_social(project_id: int, platform: str = "twitter", db: AsyncSession = Depends(get_db)):
    """Generate social media content from the transcript"""
    from services import llm_service
    
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalars().first()
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        raise HTTPException(status_code=500, detail="Failed to parse transcript")
    
    return await llm_service.generate_social_content(segments, platform)

@app.post("/projects/{project_id}/blog")
async def generate_blog(project_id: int, db: AsyncSession = Depends(get_db)):
    """Generate a blog post from the transcript"""
    from services import llm_service
    
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalars().first()
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        raise HTTPException(status_code=500, detail="Failed to parse transcript")
    
    return await llm_service.generate_blog_post(segments)

# ========== TTS Dubbing Endpoints ==========

@app.post("/projects/{project_id}/dub")
async def generate_dub(
    project_id: int, 
    lang: str = "en", 
    gender: str = "female",
    db: AsyncSession = Depends(get_db)
):
    """Generate TTS audio for the transcript"""
    from services import tts_service
    
    result = await db.execute(select(Transcript).where(Transcript.project_id == project_id))
    transcript = result.scalars().first()
    if not transcript:
        raise HTTPException(status_code=404, detail="Transcript not found")
    
    import ast
    try:
        segments = ast.literal_eval(transcript.content)
    except:
        raise HTTPException(status_code=500, detail="Failed to parse transcript")
    
    output_dir = f"downloads/project_{project_id}"
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, f"dub_{lang}_{gender}.mp3")
    
    result = await tts_service.generate_full_dub(segments, output_path, lang, gender)
    
    if result:
        return {"status": "success", "audio_path": result, "download_url": f"/projects/{project_id}/dub/download?lang={lang}&gender={gender}"}
    else:
        raise HTTPException(status_code=500, detail="TTS generation failed")

@app.get("/projects/{project_id}/dub/download")
async def download_dub(project_id: int, lang: str = "en", gender: str = "female"):
    """Download the generated TTS audio"""
    output_path = f"downloads/project_{project_id}/dub_{lang}_{gender}.mp3"
    
    if not os.path.exists(output_path):
        raise HTTPException(status_code=404, detail="Dub not found. Generate it first.")
    
    return FileResponse(
        output_path, 
        media_type="audio/mpeg",
        filename=f"dub_{project_id}_{lang}_{gender}.mp3"
    )

@app.get("/tts/voices")
async def get_tts_voices():
    """Get available TTS voices"""
    from services import tts_service
    return tts_service.get_available_voices()
