"""
Clean Transcriber Service - Transcribes audio using Whisper with optional diarization
"""
import os
import asyncio
from typing import Dict, Any, Optional
import subprocess
import logging

logger = logging.getLogger(__name__)

class TranscriberService:
    def __init__(self, cache_dir: str = "./cache"):
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
    
    async def transcribe(self, video_path: str, project_id: int,
                        diarize: bool = False) -> Dict[str, Any]:
        """
        Transcribe video/audio file using Whisper
        
        Args:
            video_path: Path to video file
            project_id: Project ID for caching
            diarize: Whether to perform speaker diarization
            
        Returns:
            Dict with transcript, segments, and speaker info
        """
        try:
            audio_input = video_path # Pass video directly to faster-whisper
            
            # Use faster-whisper for transcription
            # Note: This requires faster-whisper to be installed
            try:
                from faster_whisper import WhisperModel
                
                def _transcribe_params(input_path):
                    model_size = "base"
                    model = WhisperModel(model_size, device="cpu", compute_type="int8")
                    
                    segments, info = model.transcribe(
                        input_path,
                        beam_size=5,
                        vad_filter=True
                    )
                    
                    # Consume generator to force processing in thread
                    result_segments = list(segments)
                    return result_segments, info

                segments, info = await asyncio.to_thread(_transcribe_params, audio_input)
                
                transcript_text = ""
                segments_list = []
                
                for segment in segments:
                    segment_text = segment.text.strip()
                    transcript_text += segment_text + " "
                    
                    segments_list.append({
                        "start": segment.start,
                        "end": segment.end,
                        "text": segment_text,
                        "speaker": "Speaker_1"  # Default, will be updated if diarizing
                    })
                
                # Perform speaker diarization if requested
                if diarize:
                    try:
                        from .diarizer import diarize_audio, merge_segments_with_speakers
                        logger.info(f"Running speaker diarization for project {project_id}...")
                        speaker_segments = diarize_audio(video_path)
                        if speaker_segments:
                            segments_list = merge_segments_with_speakers(segments_list, speaker_segments)
                            logger.info(f"Diarization complete: {len(speaker_segments)} speaker segments")
                    except ImportError:
                        logger.warning("Diarization module not available, skipping speaker diarization")
                    except Exception as e:
                        logger.error(f"Diarization failed: {e}")
                
                return {
                    "success": True,
                    "transcript": transcript_text.strip(),
                    "segments": segments_list,
                    "language": info.language,
                    "duration": info.duration,
                }
                
            except ImportError:
                # Fallback: Use whisper via command line
                return await self._transcribe_fallback(video_path, project_id)
                
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def _transcribe_fallback(self, audio_path: str, project_id: int) -> Dict[str, Any]:
        """Fallback transcription using whisper command line"""
        try:
            output_path = f"{self.cache_dir}/{project_id}_transcript.txt"
            
            cmd = [
                "whisper", audio_path,
                "--model", "base",
                "--output_dir", self.cache_dir,
                "--output_format", "txt",
                "--verbose", "False"
            ]
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            await process.communicate()
            
            # Read the generated transcript
            if os.path.exists(output_path):
                with open(output_path, 'r', encoding='utf-8') as f:
                    transcript = f.read()
                
                # Clean up
                os.remove(output_path)
                if os.path.exists(audio_path):
                    os.remove(audio_path)
                
                return {
                    "success": True,
                    "transcript": transcript.strip(),
                    "segments": [],
                    "language": "unknown",
                    "duration": 0,
                }
            else:
                raise Exception("Transcript file not generated")
                
        except Exception as e:
            return {
                "success": False,
                "error": f"Fallback transcription failed: {str(e)}",
                "error_type": type(e).__name__
            }
    
