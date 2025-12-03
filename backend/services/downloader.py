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
    Returns a dictionary with metadata and file path.
    
    NOTE: If FFmpeg is not installed, this will download the best audio format available
    without conversion. Install FFmpeg for MP3 conversion.
    """
    output_template = str(DOWNLOAD_DIR / f"{project_id}_%(title)s.%(ext)s")
    
    # Try with FFmpeg first, fall back to direct download if not available
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': output_template,
        'quiet': False,  # Show output for debugging
        'no_warnings': False,
        'nocheckcertificate': True,
        'ignoreerrors': False,
        'default_search': 'auto',
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    }
    
    # Try to use FFmpeg if available, otherwise just download best audio
    try:
        ydl_opts['postprocessors'] = [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }]
        ffmpeg_available = True
    except:
        logger.warning("FFmpeg not available, downloading audio in original format")
        ffmpeg_available = False

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
    expected_ext = 'mp3' if ffmpeg_available else info.get('ext', 'webm')
    filename = str(DOWNLOAD_DIR / f"{project_id}_{title}.{expected_ext}")
    
    # Try to find the file that was actually created
    actual_files = list(DOWNLOAD_DIR.glob(f"{project_id}_*"))
    if actual_files:
        filename = str(actual_files[0])  # Use the first match
    
    return {
        "title": info.get("title"),
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "file_path": filename
    }
