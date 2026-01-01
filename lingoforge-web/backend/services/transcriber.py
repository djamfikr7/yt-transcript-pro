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
        print(f"🎙️ Starting transcription for project {project_id}: {video_path}")
        try:
            audio_input = video_path # Pass video directly to faster-whisper
            
            # Use faster-whisper for transcription
            # Note: This requires faster-whisper to be installed
            try:
                from faster_whisper import WhisperModel
                print(f"📦 faster-whisper imported successfully")
                
                def _transcribe_params(input_path):
                    model_size = "base"
                    # Force CPU to avoid CUDA/cuDNN compatibility issues
                    # TODO: Fix CUDA compatibility when cuDNN libraries are properly aligned
                    device = "cpu"
                    compute_type = "int8"
                    
                    print(f"🔧 Loading Whisper model: size={model_size}, device={device}, compute_type={compute_type}")
                    
                    try:
                        model = WhisperModel(model_size, device=device, compute_type=compute_type)
                        print(f"✅ Whisper model loaded successfully")
                    except Exception as e:
                        print(f"⚠️ Failed to load Whisper model with {device}: {e}")
                        # Try loading with int32 compute type as fallback
                        try:
                            model = WhisperModel(model_size, device=device, compute_type="int32")
                            print(f"✅ Loaded Whisper model with int32 compute type")
                        except Exception as e2:
                            print(f"⚠️ Failed to load Whisper model with int32: {e2}")
                            # If all attempts fail, return None to trigger fallback method
                            print(f"⚠️ All Whisper model loading attempts failed, triggering fallback transcription method")
                            return None
                    
                    print(f"🎙️ Starting transcription on: {input_path}")
                    segments, info = model.transcribe(
                        input_path,
                        beam_size=5,
                        vad_filter=True
                    )
                    
                    # Consume generator to force processing in thread
                    result_segments = list(segments)
                    print(f"📝 Transcription complete: {len(result_segments)} segments, language={info.language}")
                    return result_segments, info

                print(f"🔄 Running transcription in thread...")
                segments, info = await asyncio.to_thread(_transcribe_params, audio_input)
                print(f"🔄 Transcription thread completed")
                
                # Check if transcription failed (returned None)
                if segments is None or info is None:
                    print(f"⚠️ Transcription returned None, triggering fallback method")
                    return await self._transcribe_fallback(video_path, project_id)
                
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
        print(f"🔄 Fallback transcription triggered for project {project_id}: {audio_path}")
        try:
            # Use JSON output format to get segments with timestamps
            output_base = f"{self.cache_dir}/{project_id}_transcript"
            
            cmd = [
                "whisper", audio_path,
                "--model", "base",
                "--output_dir", self.cache_dir,
                "--output_format", "json",  # Use JSON for segments
                "--verbose", "False"
            ]
            print(f"🔧 Running whisper command: {' '.join(cmd)}")
            
            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            
            await process.communicate()
            
            # Read the generated transcript JSON
            json_path = f"{output_base}.json"
            if os.path.exists(json_path):
                import json
                with open(json_path, 'r', encoding='utf-8') as f:
                    transcript_data = json.load(f)
                
                # Parse segments from JSON
                segments_list = []
                transcript_text = ""
                
                for segment in transcript_data.get('segments', []):
                    segment_text = segment.get('text', '').strip()
                    if segment_text:
                        transcript_text += segment_text + " "
                        segments_list.append({
                            "start": segment.get('start', 0),
                            "end": segment.get('end', 0),
                            "text": segment_text,
                            "speaker": "Speaker_1"
                        })
                
                # Clean up
                os.remove(json_path)
                
                # Also remove any other generated files
                for ext in ['txt', 'srt', 'vtt']:
                    other_file = f"{output_base}.{ext}"
                    if os.path.exists(other_file):
                        os.remove(other_file)
                
                return {
                    "success": True,
                    "transcript": transcript_text.strip(),
                    "segments": segments_list,
                    "language": transcript_data.get('language', 'unknown'),
                    "duration": transcript_data.get('duration', 0),
                }
            else:
                raise Exception("Transcript file not generated")
                
        except Exception as e:
            return {
                "success": False,
                "error": f"Fallback transcription failed: {str(e)}",
                "error_type": type(e).__name__
            }
    
