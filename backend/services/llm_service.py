# LLM Content Repurposing Service
# Provides summarization, key points extraction, and social media content generation
import logging
import os
import google.generativeai as genai

logger = logging.getLogger(__name__)

# Initialize Gemini client
_model = None

def get_model():
    global _model
    if _model is None:
        api_key = os.environ.get("GOOGLE_API_KEY") or os.environ.get("GEMINI_API_KEY")
        if api_key:
            genai.configure(api_key=api_key)
            _model = genai.GenerativeModel('gemini-1.5-flash')
            logger.info("Gemini model initialized")
        else:
            logger.warning("No GOOGLE_API_KEY found, LLM features disabled")
            return None
    return _model

def get_full_text(segments):
    """Extract full text from transcript segments"""
    return " ".join([seg.get('text', '').strip() for seg in segments])

async def summarize(segments, style="concise"):
    """
    Generate a summary of the transcript.
    Styles: concise, detailed, bullet_points
    """
    model = get_model()
    if not model:
        return {"error": "LLM not configured", "summary": ""}
    
    text = get_full_text(segments)
    if not text:
        return {"error": "No text to summarize", "summary": ""}
    
    prompts = {
        "concise": f"Summarize this transcript in 2-3 sentences:\n\n{text}",
        "detailed": f"Provide a detailed summary of this transcript in 4-6 paragraphs:\n\n{text}",
        "bullet_points": f"Summarize this transcript as 5-10 bullet points:\n\n{text}"
    }
    
    try:
        response = model.generate_content(prompts.get(style, prompts["concise"]))
        return {"summary": response.text, "style": style}
    except Exception as e:
        logger.error(f"Summarization error: {e}")
        return {"error": str(e), "summary": ""}

async def extract_key_points(segments, count=5):
    """Extract key points/takeaways from the transcript"""
    model = get_model()
    if not model:
        return {"error": "LLM not configured", "key_points": []}
    
    text = get_full_text(segments)
    if not text:
        return {"error": "No text to analyze", "key_points": []}
    
    prompt = f"""Extract the {count} most important key points or takeaways from this transcript.
Format as a numbered list.

Transcript:
{text}"""
    
    try:
        response = model.generate_content(prompt)
        # Parse numbered list
        lines = response.text.strip().split('\n')
        key_points = [line.strip() for line in lines if line.strip()]
        return {"key_points": key_points}
    except Exception as e:
        logger.error(f"Key points extraction error: {e}")
        return {"error": str(e), "key_points": []}

async def generate_social_content(segments, platform="twitter"):
    """Generate social media content from the transcript"""
    model = get_model()
    if not model:
        return {"error": "LLM not configured", "content": ""}
    
    text = get_full_text(segments)
    if not text:
        return {"error": "No text to process", "content": ""}
    
    prompts = {
        "twitter": f"""Create a compelling Twitter/X thread (5-7 tweets) from this transcript.
Each tweet should be under 280 characters.
Use engaging hooks and include relevant hashtags.

Transcript:
{text}""",
        "linkedin": f"""Create a professional LinkedIn post from this transcript.
Include key insights and a call to action.
Keep it under 1300 characters.

Transcript:
{text}""",
        "youtube_description": f"""Create a YouTube video description from this transcript.
Include:
- Hook/summary (2-3 sentences)
- Key timestamps (make up reasonable ones)
- Call to action
- Relevant tags

Transcript:
{text}"""
    }
    
    try:
        response = model.generate_content(prompts.get(platform, prompts["twitter"]))
        return {"content": response.text, "platform": platform}
    except Exception as e:
        logger.error(f"Social content generation error: {e}")
        return {"error": str(e), "content": ""}

async def generate_blog_post(segments):
    """Generate a blog post from the transcript"""
    model = get_model()
    if not model:
        return {"error": "LLM not configured", "blog": ""}
    
    text = get_full_text(segments)
    if not text:
        return {"error": "No text to process", "blog": ""}
    
    prompt = f"""Transform this transcript into a well-structured blog post.
Include:
- Catchy title
- Introduction
- Main sections with headings
- Conclusion
- Call to action

Format in Markdown.

Transcript:
{text}"""
    
    try:
        response = model.generate_content(prompt)
        return {"blog": response.text}
    except Exception as e:
        logger.error(f"Blog generation error: {e}")
        return {"error": str(e), "blog": ""}
