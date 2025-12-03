from faster_whisper import WhisperModel
import asyncio
from pathlib import Path

# Model configuration
MODEL_SIZE = "base" # Can be tiny, base, small, medium, large-v2
COMPUTE_TYPE = "int8" # Use int8 for CPU efficiency, float16 for GPU

class Transcriber:
    def __init__(self):
        # Initialize model on first use or startup
        # For now, we'll load it lazily or here
        self.model = None

    def load_model(self):
        if not self.model:
            print(f"Loading Whisper model: {MODEL_SIZE}...")
            self.model = WhisperModel(MODEL_SIZE, device="cpu", compute_type=COMPUTE_TYPE)
            print("Model loaded.")

    async def transcribe(self, audio_path: str) -> dict:
        """
        Transcribes audio file using faster-whisper.
        Returns a list of segments with timestamps.
        """
        if not self.model:
            self.load_model()

        def _run_transcribe():
            segments, info = self.model.transcribe(audio_path, beam_size=5)
            # Convert generator to list
            result_segments = []
            for segment in segments:
                result_segments.append({
                    "start": segment.start,
                    "end": segment.end,
                    "text": segment.text
                })
            return result_segments, info

        # Run blocking transcription in a separate thread
        loop = asyncio.get_event_loop()
        segments, info = await loop.run_in_executor(None, _run_transcribe)

        return {
            "language": info.language,
            "language_probability": info.language_probability,
            "segments": segments
        }

# Global instance
transcriber = Transcriber()
