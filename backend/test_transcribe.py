import asyncio
from services.transcriber import transcriber
import sys

async def test_transcription():
    audio_file = 'downloads/4_Me at the zoo.webm'
    print(f"Testing transcription on: {audio_file}")
    
    try:
        result = await transcriber.transcribe(audio_file)
        print(f"\n✅ Transcription successful!")
        print(f"Language: {result['language']}")
        print(f"Segments: {len(result['segments'])}")
        print(f"\nFirst 3 segments:")
        for seg in result['segments'][:3]:
            print(f"  [{seg['start']:.2f}s - {seg['end']:.2f}s]: {seg['text']}")
    except Exception as e:
        print(f"\n❌ Transcription failed: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_transcription())
