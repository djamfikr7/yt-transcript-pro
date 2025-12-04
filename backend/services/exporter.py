# Transcript Export Service
# Converts segments to SRT, VTT, and TXT formats

def format_timestamp_srt(seconds: float) -> str:
    """Convert seconds to SRT timestamp format: HH:MM:SS,mmm"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds - int(seconds)) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d},{millis:03d}"

def format_timestamp_vtt(seconds: float) -> str:
    """Convert seconds to VTT timestamp format: HH:MM:SS.mmm"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    millis = int((seconds - int(seconds)) * 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"

def to_srt(segments: list) -> str:
    """Convert transcript segments to SRT subtitle format"""
    lines = []
    for i, seg in enumerate(segments, 1):
        start = seg.get('start', 0)
        end = seg.get('end', 0)
        text = seg.get('text', '').strip()
        speaker = seg.get('speaker', '')
        
        if speaker:
            text = f"[{speaker}] {text}"
        
        lines.append(str(i))
        lines.append(f"{format_timestamp_srt(start)} --> {format_timestamp_srt(end)}")
        lines.append(text)
        lines.append("")  # Blank line between entries
    
    return "\n".join(lines)

def to_vtt(segments: list) -> str:
    """Convert transcript segments to WebVTT subtitle format"""
    lines = ["WEBVTT", ""]  # VTT header
    
    for i, seg in enumerate(segments, 1):
        start = seg.get('start', 0)
        end = seg.get('end', 0)
        text = seg.get('text', '').strip()
        speaker = seg.get('speaker', '')
        
        if speaker:
            text = f"<v {speaker}>{text}"
        
        lines.append(f"{format_timestamp_vtt(start)} --> {format_timestamp_vtt(end)}")
        lines.append(text)
        lines.append("")
    
    return "\n".join(lines)

def to_txt(segments: list) -> str:
    """Convert transcript segments to plain text with timestamps"""
    lines = []
    for seg in segments:
        start = seg.get('start', 0)
        text = seg.get('text', '').strip()
        speaker = seg.get('speaker', '')
        
        # Format: [MM:SS] [SPEAKER] Text
        mins = int(start // 60)
        secs = int(start % 60)
        timestamp = f"[{mins:02d}:{secs:02d}]"
        
        if speaker:
            lines.append(f"{timestamp} [{speaker}] {text}")
        else:
            lines.append(f"{timestamp} {text}")
    
    return "\n".join(lines)
