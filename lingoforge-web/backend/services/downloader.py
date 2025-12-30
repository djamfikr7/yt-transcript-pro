"""
Clean Downloader Service - Downloads YouTube videos and extracts metadata
"""
import os
import asyncio
from typing import Optional, Dict, Any
import yt_dlp

class DownloaderService:
    def __init__(self, download_dir: str = "./downloads"):
        self.download_dir = download_dir
        os.makedirs(download_dir, exist_ok=True)
    
    async def download_video(self, url: str, project_id: int, progress_callback=None) -> Dict[str, Any]:
        """
        Download video from YouTube URL (Non-blocking)
        
        Args:
            url: YouTube video URL
            project_id: Project ID for file naming
            progress_callback: Optional callback function(percent: int)
            
        Returns:
            Dict with video_path, title, duration, thumbnail
        """
        try:
            output_path = os.path.join(self.download_dir, f"{project_id}")
            
            # IMPORTANT: Clean up any existing files for this project ID first
            # This prevents using stale/old video files
            import glob
            for old_file in glob.glob(f"{output_path}.*"):
                try:
                    os.remove(old_file)
                    print(f"🧹 Cleaned up old file: {old_file}")
                except Exception as e:
                    print(f"⚠️ Could not clean up {old_file}: {e}")

            # Enforce storage limit (auto-cleanup old files)
            self._enforce_storage_limit(limit_gb=10)
            
            ydl_opts = {
                'outtmpl': f'{output_path}.%(ext)s',
                'format': 'best[height<=720]/best',
                'quiet': True,
                'no_warnings': True,
                'noplaylist': True,
                'overwrites': False,   # CHANGED: Allow resume (was True)
                'continuedl': True,    # Explicitly enable resume
                'retries': float('inf'), # Infinite retries for network errors
                'fragment_retries': float('inf'),
                'file_access_retries': 10,
                'socket_timeout': 30,
            }
            
            # Run download with outer retry loop for resilience
            max_retries = 999999 # Effectively infinite
            retry_count = 0
            backoff = 5
            
            # Shared state for progress tracking across retries/threads
            state = {'progress': 0}
            
            while retry_count < max_retries:
                try:
                    # Run blocking download in a separate thread
                    def _download():
                        # Progress hook for yt-dlp
                        def progress_hook(d):
                            if d['status'] == 'downloading':
                                try:
                                    p = d.get('_percent_str', '').replace('%','')
                                    import re
                                    p = re.sub(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])', '', p)
                                    if p and progress_callback:
                                        percent = float(p)
                                        state['progress'] = int(percent)
                                        progress_callback(int(percent), 'downloading')
                                except Exception:
                                    pass

                        opts = ydl_opts.copy()
                        opts['progress_hooks'] = [progress_hook]

                        with yt_dlp.YoutubeDL(opts) as ydl:
                            info = ydl.extract_info(url, download=True)
                            video_path = ydl.prepare_filename(info)
                            return info, video_path

                    info, video_path = await asyncio.to_thread(_download)
                    
                    return {
                        "success": True,
                        "video_path": video_path,
                        "title": info.get('title', 'Unknown'),
                        "duration": info.get('duration', 0),
                        "thumbnail": info.get('thumbnail', ''),
                        "ext": info.get('ext', 'mp4'),
                    }
                    
                except Exception as e:
                    retry_count += 1
                    err_msg = str(e)
                    print(f"⚠️ Download error (attempt {retry_count}): {e}")
                    
                    if progress_callback:
                        progress_callback(state['progress'], 'retrying')
                        
                    print(f"⏳ Retrying in {backoff} seconds...")
                    await asyncio.sleep(backoff)
                    backoff = min(backoff * 1.5, 60) # Cap backoff at 60s
                    
            raise Exception("Max retries exceeded") # Should not be reached with infinite retries
                
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def get_video_info(self, url: str) -> Dict[str, Any]:
        """Get video information without downloading"""
        try:
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'skip_download': True,
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                
                return {
                    "success": True,
                    "title": info.get('title', 'Unknown'),
                    "duration": info.get('duration', 0),
                    "thumbnail": info.get('thumbnail', ''),
                    "url": url,
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }

    async def get_playlist_info(self, url: str) -> Dict[str, Any]:
        """Extract videos from playlist"""
        try:
            ydl_opts = {
                'extract_flat': True,
                'quiet': True,
                'no_warnings': True,
                'ignoreerrors': True,
            }
            
            def _extract():
                with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                    return ydl.extract_info(url, download=False)
            
            info = await asyncio.to_thread(_extract)
            
            if 'entries' in info:
                videos = []
                for entry in info['entries']:
                    if not entry: continue
                    v_url = entry.get('url')
                    title = entry.get('title', 'Unknown')
                    if not v_url:
                        if entry.get('id'):
                            v_url = f"https://www.youtube.com/watch?v={entry.get('id')}"
                        else:
                            continue
                            
                    # Ensure full URL for YouTube
                    if 'youtube.com' not in v_url and 'youtu.be' not in v_url:
                        v_url = f"https://www.youtube.com/watch?v={v_url}"
                        
                    videos.append({"url": v_url, "title": title})
                
                return {
                    "success": True, 
                    "videos": videos, 
                    "title": info.get('title', 'Playlist'),
                    "count": len(videos)
                }
            else:
                 # Single video?
                 return {"success": False, "error": "Not a playlist or empty"}
                 
        except Exception as e:
            return {"success": False, "error": str(e)}
        """Clean up downloaded files for a project"""
        try:
            pattern = os.path.join(self.download_dir, f"{project_id}.*")
            import glob
            for file in glob.glob(pattern):
                if os.path.exists(file):
                    os.remove(file)
        except Exception:
            pass

    def _enforce_storage_limit(self, limit_gb: int):
        """Enforce storage limit by deleting oldest files"""
        try:
            files = []
            total_size = 0
            # Scan directory
            for f in os.listdir(self.download_dir):
                fp = os.path.join(self.download_dir, f)
                if os.path.isfile(fp):
                    size = os.path.getsize(fp)
                    total_size += size
                    files.append((fp, os.path.getmtime(fp), size))
            
            # Sort by modification time (oldest first)
            files.sort(key=lambda x: x[1])
            
            limit_bytes = limit_gb * 1024 * 1024 * 1024
            
            if total_size > limit_bytes:
                print(f"🧹 Storage limit exceeded ({total_size/1024/1024/1024:.2f}GB > {limit_gb}GB). Cleaning up...")
                while total_size > limit_bytes and files:
                    f_path, _, f_size = files.pop(0)
                    try:
                        os.remove(f_path)
                        total_size -= f_size
                        print(f"   Deleted old file: {os.path.basename(f_path)}")
                    except Exception:
                        pass
        except Exception as e:
            print(f"⚠️ Storage cleanup error: {e}")
