"""
Clean Downloader Service - Downloads YouTube videos and extracts metadata
Enhanced with resume/skip functionality to prevent data waste
"""
import os
import asyncio
from typing import Optional, Dict, Any
import yt_dlp
import glob

class DownloaderService:
    def __init__(self, download_dir: str = "./downloads"):
        self.download_dir = download_dir
        os.makedirs(download_dir, exist_ok=True)
    
    def _find_existing_video_file(self, project_id: int) -> Optional[str]:
        """
        Find an existing video file for the given project ID.
        
        Args:
            project_id: Project ID to search for
            
        Returns:
            Path to existing file if found, None otherwise
        """
        pattern = os.path.join(self.download_dir, f"{project_id}.*")
        matching_files = glob.glob(pattern)
        
        # Filter to common video extensions
        video_extensions = ['.mp4', '.mkv', '.webm', '.avi', '.mov', '.flv']
        for file_path in matching_files:
            if os.path.splitext(file_path)[1].lower() in video_extensions:
                return file_path
        
        return None
    
    def _get_video_metadata(self, url: str) -> Optional[Dict[str, Any]]:
        """
        Get video metadata without downloading.
        
        Args:
            url: YouTube video URL
            
        Returns:
            Dict with duration, expected_size (estimated), title, or None on error
        """
        try:
            ydl_opts = {
                'quiet': True,
                'no_warnings': True,
                'skip_download': True,
                'format': 'best[height<=720]/best',  # Match the format used in download
            }
            
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(url, download=False)
                
                # Get duration
                duration = info.get('duration', 0)
                
                # Try to get file size from the selected format
                expected_size = None
                
                # Check if we have format information with file size
                if 'formats' in info and info['formats']:
                    # Find the format that would be selected
                    # Prefer formats with explicit file sizes
                    for fmt in info['formats']:
                        if 'filesize' in fmt and fmt['filesize']:
                            expected_size = fmt['filesize']
                            break
                        elif 'filesize_approx' in fmt and fmt['filesize_approx']:
                            expected_size = fmt['filesize_approx']
                
                # If no format size, try top-level info
                if not expected_size:
                    if 'filesize' in info and info['filesize']:
                        expected_size = info['filesize']
                    elif 'filesize_approx' in info and info['filesize_approx']:
                        expected_size = info['filesize_approx']
                
                # Fallback estimation if still no size
                if not expected_size and duration > 0:
                    # Conservative estimation based on typical YouTube bitrates
                    # - 480p: ~0.3-0.5 MB/s
                    # - 720p: ~0.8-1.2 MB/s
                    # - 1080p: ~1.5-2.5 MB/s
                    height = info.get('height', 0)
                    if height >= 1080:
                        expected_size = duration * 2 * 1024 * 1024  # 2MB/s
                    elif height >= 720:
                        expected_size = duration * 1 * 1024 * 1024  # 1MB/s
                    else:
                        expected_size = duration * 0.5 * 1024 * 1024  # 0.5MB/s
                    
                    # Sanity check: if expected size is > 5GB, cap it
                    # Most YouTube videos are < 5GB
                    if expected_size > 5 * 1024 * 1024 * 1024:
                        expected_size = 5 * 1024 * 1024 * 1024
                        print(f"⚠️ Estimated file size capped at 5GB for {duration}s video")
                
                print(f"📊 Video metadata: duration={duration}s, expected_size={expected_size/1024/1024:.2f}MB if expected_size else 'unknown'")
                
                return {
                    'duration': duration,
                    'expected_size': expected_size,
                    'title': info.get('title', 'Unknown'),
                    'thumbnail': info.get('thumbnail', ''),
                    'ext': info.get('ext', 'mp4'),
                    'height': info.get('height', 0),
                }
        except Exception as e:
            print(f"⚠️ Failed to get video metadata: {e}")
            return None
    
    def _is_file_complete(self, file_path: str, metadata: Dict[str, Any]) -> bool:
        """
        Check if an existing file is complete by comparing sizes.
        
        Args:
            file_path: Path to the existing file
            metadata: Video metadata with expected_size
            
        Returns:
            True if file is complete, False otherwise
        """
        try:
            actual_size = os.path.getsize(file_path)
            expected_size = metadata.get('expected_size')
            
            if expected_size is None:
                # If we don't have expected size, check if file has reasonable size
                # A complete video should be at least 100KB
                return actual_size > 100 * 1024
            
            # Calculate size ratio
            size_ratio = actual_size / expected_size
            
            # Consider complete if within 80-120% of expected size
            # OR if actual size is significantly larger (estimation was wrong)
            # This handles cases where:
            # - Video is slightly smaller due to compression (80-100%)
            # - Video is slightly larger due to different encoding (100-120%)
            # - Metadata estimation was way off (>120% but file is clearly complete)
            if 0.8 <= size_ratio <= 1.2:
                return True
            elif size_ratio > 1.2:
                # File is larger than expected - could be estimation error
                # If file is > 50MB and > 2x expected, it's likely complete
                if actual_size > 50 * 1024 * 1024:  # > 50MB
                    print(f"⚠️ File size ({actual_size/1024/1024:.2f}MB) exceeds estimate ({expected_size/1024/1024:.2f}MB), assuming complete")
                    return True
                return False
            else:
                # File is smaller than 80% of expected - incomplete
                return False
            
        except Exception as e:
            print(f"⚠️ Error checking file completeness: {e}")
            return False
    
    async def download_video(self, url: str, project_id: int, progress_callback=None) -> Dict[str, Any]:
        """
        Download video from YouTube URL with resume/skip logic.
        
        Logic:
        1. Get video metadata (expected size, duration, title)
        2. Check if video file already exists for this project_id
        3. If file exists:
           a. Check if file size matches expected size
           b. If complete: Skip download, return existing file path
           c. If incomplete: Resume download with continuedl=True
        4. If file doesn't exist: Start fresh download
        
        Args:
            url: YouTube video URL
            project_id: Project ID for file naming
            progress_callback: Optional callback function(percent: int)
            
        Returns:
            Dict with video_path, title, duration, thumbnail
        """
        try:
            output_path = os.path.join(self.download_dir, f"{project_id}")
            
            # Step 1: Get video metadata
            metadata = self._get_video_metadata(url)
            if not metadata:
                print(f"⚠️ Could not get metadata for {url}, proceeding with download anyway")
            
            # Step 2: Check for existing file
            existing_file = self._find_existing_video_file(project_id)
            
            # Step 3: If file exists, check if it's complete
            if existing_file and metadata:
                print(f"🔍 Found existing file: {existing_file}")
                
                if self._is_file_complete(existing_file, metadata):
                    # File is complete - skip download
                    print(f"✅ File is complete ({os.path.getsize(existing_file) / 1024 / 1024:.2f}MB), skipping download")
                    
                    # Get file extension
                    file_ext = os.path.splitext(existing_file)[1][1:]  # Remove the dot
                    
                    return {
                        "success": True,
                        "video_path": existing_file,
                        "title": metadata.get('title', os.path.basename(existing_file)),
                        "duration": metadata.get('duration', 0),
                        "thumbnail": metadata.get('thumbnail', ''),
                        "ext": file_ext,
                        "skipped": True,  # Flag to indicate download was skipped
                    }
                else:
                    # File is incomplete - will resume
                    actual_size = os.path.getsize(existing_file)
                    expected_size = metadata.get('expected_size', 0)
                    print(f"📥 File is incomplete ({actual_size / 1024 / 1024:.2f}MB / {expected_size / 1024 / 1024:.2f}MB), resuming download")
            elif existing_file and not metadata:
                # File exists but no metadata - assume incomplete and try to resume
                print(f"📥 Found existing file but no metadata, attempting to resume")
            
            # Step 4: Enforce storage limit (auto-cleanup old files)
            self._enforce_storage_limit(limit_gb=10)
            
            # Step 5: Configure yt-dlp for download/resume
            ydl_opts = {
                'outtmpl': f'{output_path}.%(ext)s',
                'format': 'best[height<=720]/best',
                'quiet': True,
                'no_warnings': True,
                'noplaylist': True,
                'overwrites': False,   # Allow resume (don't overwrite existing files)
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
            
            # If we have an existing partial file, start progress from where we left off
            if existing_file and metadata:
                actual_size = os.path.getsize(existing_file)
                expected_size = metadata.get('expected_size', 1)
                initial_percent = int((actual_size / expected_size) * 100)
                state['progress'] = min(initial_percent, 99)  # Cap at 99% initially
                print(f"📊 Starting from {state['progress']}% progress")
            
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
                                        # If resuming, add existing progress
                                        if existing_file and metadata and retry_count == 0:
                                            actual_size = os.path.getsize(existing_file)
                                            expected_size = metadata.get('expected_size', 1)
                                            base_percent = int((actual_size / expected_size) * 100)
                                            percent = min(base_percent + percent, 100)
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
                        "skipped": False,
                    }
                    
                except Exception as e:
                    retry_count += 1
                    err_msg = str(e)
                    
                    # Check for 429 rate limit error
                    is_429_error = (
                        '429' in err_msg or
                        'Too Many Requests' in err_msg or
                        'HTTP Error 429' in err_msg
                    )
                    
                    if is_429_error:
                        # Use exponential backoff for 429 errors (longer wait times)
                        print(f"⚠️ Rate limit hit (429), attempt {retry_count}")
                        if progress_callback:
                            progress_callback(state['progress'], 'retrying')
                        print(f"⏳ Rate limited, waiting {backoff}s before retry...")
                        await asyncio.sleep(backoff)
                        # More aggressive backoff for 429: double the time
                        backoff = min(backoff * 2, 300)  # Cap at 5 minutes
                    else:
                        # Standard error handling
                        print(f"⚠️ Download error (attempt {retry_count}): {e}")
                        if progress_callback:
                            progress_callback(state['progress'], 'retrying')
                        print(f"⏳ Retrying in {backoff} seconds...")
                        await asyncio.sleep(backoff)
                        backoff = min(backoff * 1.5, 60)  # Cap at 60s
                    
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
    
    def cleanup_project(self, project_id: int):
        """Clean up downloaded files for a project"""
        try:
            pattern = os.path.join(self.download_dir, f"{project_id}.*")
            for file in glob.glob(pattern):
                if os.path.exists(file):
                    os.remove(file)
                    print(f"🧹 Cleaned up file: {file}")
        except Exception as e:
            print(f"⚠️ Cleanup error: {e}")

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
