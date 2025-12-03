import yt_dlp
import asyncio
import os
from pathlib import Path

# Configure download directory
DOWNLOAD_DIR = Path("downloads")
DOWNLOAD_DIR.mkdir(exist_ok=True)

async def download_audio(url: str, project_id: int) -> dict:
    """
    Downloads audio from a YouTube URL using yt-dlp.
    Returns a dictionary with metadata and file path.
    """
    output_template = str(DOWNLOAD_DIR / f"{project_id}_%(title)s.%(ext)s")
    
    ydl_opts = {
        'format': 'bestaudio/best',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'outtmpl': output_template,
        'quiet': True,
        'no_warnings': True,
        'nocheckcertificate': True,
        'ignoreerrors': False,
        'logtostderr': False,
        'quiet': True,
        'no_warnings': True,
        'default_search': 'auto',
        'source_address': '0.0.0.0',  # bind to ipv4 since ipv6 addresses cause issues sometimes
        'user_agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
    }

    def _run_download():
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            return info

    # Run blocking yt-dlp in a separate thread
    loop = asyncio.get_event_loop()
    info = await loop.run_in_executor(None, _run_download)
    
    # Find the generated file (yt-dlp might change extension)
    # Since we asked for mp3, it should be mp3
    filename = ydl_opts['outtmpl'].replace("%(title)s", info['title']).replace("%(ext)s", "mp3")
    
    # Fallback to finding the file if template replacement isn't exact
    # (Simplified for now, assuming standard behavior)
    
    return {
        "title": info.get("title"),
        "duration": info.get("duration"),
        "thumbnail": info.get("thumbnail"),
        "file_path": filename # Note: This might need robust path finding
    }
