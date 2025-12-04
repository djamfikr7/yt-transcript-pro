# Speaker Diarization Service using pyannote-audio
# Note: Requires HuggingFace token for pyannote models
import logging
import os

logger = logging.getLogger(__name__)

# Lazy loading to avoid import errors if pyannote not installed
_pipeline = None

def get_pipeline():
    global _pipeline
    if _pipeline is None:
        try:
            from pyannote.audio import Pipeline
            # Use the pre-trained speaker diarization pipeline
            # Requires: pip install pyannote.audio
            # And HuggingFace token with access to pyannote models
            hf_token = os.environ.get("HF_TOKEN", None)
            if hf_token:
                _pipeline = Pipeline.from_pretrained(
                    "pyannote/speaker-diarization-3.1",
                    use_auth_token=hf_token
                )
                logger.info("Speaker diarization pipeline loaded successfully")
            else:
                logger.warning("No HF_TOKEN found, speaker diarization will be disabled")
                return None
        except ImportError:
            logger.warning("pyannote.audio not installed, speaker diarization disabled")
            return None
        except Exception as e:
            logger.error(f"Failed to load diarization pipeline: {e}")
            return None
    return _pipeline

def diarize_audio(audio_path: str):
    """
    Perform speaker diarization on an audio file.
    Returns a list of speaker segments: [{"start": float, "end": float, "speaker": str}, ...]
    """
    pipeline = get_pipeline()
    if pipeline is None:
        logger.info("Diarization skipped (not available)")
        return []
    
    try:
        logger.info(f"Running speaker diarization on {audio_path}...")
        diarization = pipeline(audio_path)
        
        segments = []
        for turn, _, speaker in diarization.itertracks(yield_label=True):
            segments.append({
                "start": turn.start,
                "end": turn.end,
                "speaker": f"Speaker {speaker[-1]}"  # e.g., "Speaker A"
            })
        
        logger.info(f"Diarization complete: found {len(set(s['speaker'] for s in segments))} speakers")
        return segments
    except Exception as e:
        logger.error(f"Diarization error: {e}")
        return []

def merge_segments_with_speakers(transcript_segments, speaker_segments):
    """
    Merge transcript segments with speaker labels.
    Assigns speaker based on which speaker segment overlaps most with the transcript segment.
    """
    if not speaker_segments:
        return transcript_segments
    
    merged = []
    for seg in transcript_segments:
        t_start = seg.get('start', 0)
        t_end = seg.get('end', 0)
        
        # Find best matching speaker
        best_speaker = None
        best_overlap = 0
        
        for sp_seg in speaker_segments:
            sp_start = sp_seg['start']
            sp_end = sp_seg['end']
            
            # Calculate overlap
            overlap_start = max(t_start, sp_start)
            overlap_end = min(t_end, sp_end)
            overlap = max(0, overlap_end - overlap_start)
            
            if overlap > best_overlap:
                best_overlap = overlap
                best_speaker = sp_seg['speaker']
        
        new_seg = seg.copy()
        if best_speaker:
            new_seg['speaker'] = best_speaker
        merged.append(new_seg)
    
    return merged
