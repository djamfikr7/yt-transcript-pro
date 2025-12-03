import asyncio
from services.downloader import download_audio

async def test():
    print("Testing download...")
    try:
        result = await download_audio("https://www.youtube.com/watch?v=jNQXAC9IVRw", 999)
        print("Download result:", result)
    except Exception as e:
        print("Download failed:", e)

if __name__ == "__main__":
    asyncio.run(test())
