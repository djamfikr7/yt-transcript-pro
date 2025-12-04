import yt_dlp
import asyncio
import os
from pathlib import Path
import logging

logger = logging.getLogger(__name__)

# Configure download directory
DOWNLOAD_DIR = Path("downloads")
DOWNLOAD_DIR.mkdir(exist_ok=True)

async def download_audio(url: str, project_id: int) -> dict:
    """
    Downloads audio from a YouTube URL using yt-dlp.
    Downloads in native format (WebM/M4A) - NO FFmpeg required!
    Whisper can transcribe these formats directly.
    """
    output_template = str(DOWNLOAD_DIR / f"{project_id}_%(title)s.%(ext)s")
    
    # Download best audio without any postprocessing (no FFmpeg needed!)
    ydl_opts = {
        'format': 'bestaudio/best',  # Download best audio stream
        'outtmpl': output_template,
        'quiet': False,  # Show output for debugging
        'no_warnings': False,
        'nocheckcertificate': True,
        'ignoreerrors': False,
        'default_search': 'auto',
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        # NO postprocessors = NO FFmpeg required!
    }

    def _run_download():
        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=True)
                return info, None
        except Exception as e:
            logger.error(f"Download failed: {str(e)}")
            return None, str(e)

    # Run blocking yt-dlp in a separate thread
    loop = asyncio.get_event_loop()
    info, error = await loop.run_in_executor(None, _run_download)
    
    if error or not info:
        raise Exception(f"Download failed: {error}")
    
    # Find the actual downloaded file
    title = info.get('title', 'audio')
    ext = info.get('ext', 'webm')  # Usually webm, m4a, or opus
    
    # Clean title for filename
    import re
    clean_title = re.sub(r'[^\w\s-]', '', title)[:50]  # Remove special chars, limit length
    
    expected_filename = str(DOWNLOAD_DIR / f"{project_id}_{title}.{ext}")
    
    # Try to find the file that was actually created
    actual_files = list(DOWNLOAD_DIR.glob(f"{project_id}_*"))
    if actual_files:
        filename = str(actual_files[0])  # Use the first match
        logger.info(f"Found downloaded file: {filename}")
    else:
        filename = expected_filename
        logger.warning(f"Could not find downloaded file, using expected: {filename}")
    
    return {
        "title": info.get("title"),
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "file_path": filename
    }
