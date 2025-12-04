def to_srt(segments):
    """Convert segments to SRT format"""
    output = []
    for i, seg in enumerate(segments, 1):
        start = _format_timestamp(seg['start'])
        end = _format_timestamp(seg['end'])
        text = seg['text'].strip()
        output.append(f"{i}\n{start} --> {end}\n{text}\n")
    return "\n".join(output)

def to_txt(segments):
    """Convert segments to plain text"""
    return "\n".join([seg['text'].strip() for seg in segments])

def _format_timestamp(seconds):
    """Convert seconds to HH:MM:SS,mmm"""
    millis = int((seconds % 1) * 1000)
    seconds = int(seconds)
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    seconds = seconds % 60
    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{millis:03d}"
