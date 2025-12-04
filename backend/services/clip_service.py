# backend/services/clip_service.py
# Social clip generator using FFmpeg

import os
import subprocess
import logging
from typing import Optional, Tuple

logger = logging.getLogger(__name__)

def extract_clip(
    video_path: str,
    output_path: str,
    start_time: float,
    duration: float = 60,
    aspect_ratio: str = "16:9",  # 16:9, 9:16, 1:1
    max_width: int = 1080,
) -> Optional[str]:
    """
    Extract a clip from a video with specified aspect ratio.
    
    Args:
        video_path: Path to source video
        output_path: Path for output clip
        start_time: Start time in seconds
        duration: Clip duration in seconds (default 60)
        aspect_ratio: Target aspect ratio (16:9, 9:16, 1:1)
        max_width: Maximum width in pixels
    
    Returns:
        Path to output clip or None if failed
    """
    if not os.path.exists(video_path):
        logger.error(f"Video not found: {video_path}")
        return None
    
    # Determine crop and scale filters based on aspect ratio
    if aspect_ratio == "9:16":
        # Vertical (TikTok, Reels, Shorts)
        vf_filter = f"crop=ih*9/16:ih,scale={max_width}:-2"
    elif aspect_ratio == "1:1":
        # Square (Instagram feed)
        vf_filter = f"crop=min(iw\\,ih):min(iw\\,ih),scale={max_width}:{max_width}"
    else:
        # Horizontal (YouTube, default)
        vf_filter = f"scale={max_width}:-2"
    
    try:
        cmd = [
            "ffmpeg", "-y",
            "-ss", str(start_time),
            "-i", video_path,
            "-t", str(duration),
            "-vf", vf_filter,
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "23",
            "-c:a", "aac",
            "-b:a", "128k",
            output_path
        ]
        
        logger.info(f"Extracting clip: {' '.join(cmd)}")
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        
        if result.returncode == 0 and os.path.exists(output_path):
            logger.info(f"Clip extracted: {output_path}")
            return output_path
        else:
            logger.error(f"FFmpeg error: {result.stderr}")
            return None
            
    except subprocess.TimeoutExpired:
        logger.error("Clip extraction timed out")
        return None
    except Exception as e:
        logger.error(f"Clip extraction failed: {e}")
        return None

def find_highlight_moments(segments: list, count: int = 3) -> list:
    """
    Find potential highlight moments in transcript for clip extraction.
    Looks for segments with high word density and keywords.
    
    Returns list of (start_time, end_time, text) tuples.
    """
    if not segments:
        return []
    
    # Keywords that often indicate important moments
    highlight_keywords = {
        'key', 'important', 'crucial', 'amazing', 'incredible', 'secret',
        'tip', 'trick', 'hack', 'solution', 'problem', 'answer', 'why',
        'how to', 'best', 'worst', 'never', 'always', 'must', 'should',
        'first', 'finally', 'biggest', 'smallest', 'most', 'least'
    }
    
    scored_segments = []
    for i, seg in enumerate(segments):
        text = seg.get('text', '').lower()
        start = seg.get('start', 0)
        end = seg.get('end', 0)
        
        # Score based on keywords
        score = sum(1 for kw in highlight_keywords if kw in text)
        
        # Score based on exclamation/question marks
        score += text.count('!') * 0.5
        score += text.count('?') * 0.3
        
        # Prefer segments not at very start or end
        position_score = 1.0
        if i < 3:
            position_score = 0.5
        elif i > len(segments) - 3:
            position_score = 0.7
        
        score *= position_score
        
        if score > 0:
            scored_segments.append({
                'index': i,
                'start': start,
                'end': end,
                'text': seg.get('text', ''),
                'score': score
            })
    
    # Sort by score and return top moments
    scored_segments.sort(key=lambda x: x['score'], reverse=True)
    return scored_segments[:count]

def create_social_clips(
    video_path: str,
    segments: list,
    output_dir: str,
    clip_count: int = 3,
    clip_duration: float = 30,
) -> list:
    """
    Automatically create social media clips from a video.
    
    Returns list of created clip paths with metadata.
    """
    os.makedirs(output_dir, exist_ok=True)
    
    # Find highlight moments
    highlights = find_highlight_moments(segments, clip_count)
    
    clips = []
    for i, highlight in enumerate(highlights):
        start = max(0, highlight['start'] - 2)  # Start 2s before highlight
        
        for ratio in ["9:16", "1:1"]:
            ratio_slug = ratio.replace(":", "x")
            output_path = os.path.join(output_dir, f"clip_{i+1}_{ratio_slug}.mp4")
            
            result = extract_clip(
                video_path=video_path,
                output_path=output_path,
                start_time=start,
                duration=clip_duration,
                aspect_ratio=ratio
            )
            
            if result:
                clips.append({
                    'path': result,
                    'aspect_ratio': ratio,
                    'start_time': start,
                    'duration': clip_duration,
                    'highlight_text': highlight['text'][:100]
                })
    
    return clips
