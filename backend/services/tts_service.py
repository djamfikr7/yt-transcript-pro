# Text-to-Speech (TTS) Dubbing Service
# Uses edge-tts (free Microsoft Edge TTS) for voice synthesis
import logging
import os
import asyncio

logger = logging.getLogger(__name__)

# Voice options
VOICES = {
    "en": {
        "male": "en-US-GuyNeural",
        "female": "en-US-JennyNeural"
    },
    "es": {
        "male": "es-ES-AlvaroNeural",
        "female": "es-ES-ElviraNeural"
    },
    "fr": {
        "male": "fr-FR-HenriNeural",
        "female": "fr-FR-DeniseNeural"
    },
    "de": {
        "male": "de-DE-ConradNeural",
        "female": "de-DE-KatjaNeural"
    },
    "ar": {
        "male": "ar-SA-HamedNeural",
        "female": "ar-SA-ZariyahNeural"
    }
}

async def text_to_speech(text: str, output_path: str, lang: str = "en", gender: str = "female"):
    """
    Convert text to speech using edge-tts.
    Returns the path to the generated audio file.
    """
    try:
        import edge_tts
    except ImportError:
        logger.error("edge-tts not installed. Run: pip install edge-tts")
        return None
    
    # Get voice
    voice = VOICES.get(lang, VOICES["en"]).get(gender, VOICES["en"]["female"])
    
    try:
        logger.info(f"Generating TTS for {len(text)} characters using {voice}...")
        communicate = edge_tts.Communicate(text, voice)
        await communicate.save(output_path)
        logger.info(f"TTS audio saved to {output_path}")
        return output_path
    except Exception as e:
        logger.error(f"TTS error: {e}")
        return None

async def generate_dubbed_segments(segments, output_dir: str, lang: str = "en", gender: str = "female"):
    """
    Generate individual TTS audio files for each transcript segment.
    Returns a list of audio file paths.
    """
    os.makedirs(output_dir, exist_ok=True)
    audio_files = []
    
    for i, seg in enumerate(segments):
        text = seg.get('text', '').strip()
        if not text:
            continue
        
        output_path = os.path.join(output_dir, f"segment_{i:04d}.mp3")
        result = await text_to_speech(text, output_path, lang, gender)
        if result:
            audio_files.append({
                "segment_index": i,
                "start": seg.get('start', 0),
                "end": seg.get('end', 0),
                "audio_path": result
            })
    
    return audio_files

async def generate_full_dub(segments, output_path: str, lang: str = "en", gender: str = "female"):
    """
    Generate a single TTS audio file from all transcript segments.
    """
    # Combine all text
    full_text = " ".join([seg.get('text', '').strip() for seg in segments])
    
    if not full_text:
        logger.warning("No text to generate TTS for")
        return None
    
    return await text_to_speech(full_text, output_path, lang, gender)

def get_available_voices():
    """Return list of available voices by language"""
    return VOICES
