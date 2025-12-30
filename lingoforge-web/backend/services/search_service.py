"""
Clean Search Service - Semantic and keyword search across projects
"""
import os
import json
from typing import Dict, Any, List
from datetime import datetime

class SearchService:
    def __init__(self, cache_dir: str = "./cache"):
        self.cache_dir = cache_dir
        os.makedirs(cache_dir, exist_ok=True)
    
    async def search_projects(self, query: str, projects: List[Dict]) -> Dict[str, Any]:
        """
        Search across projects using keyword matching
        
        Args:
            query: Search query
            projects: List of project data
        """
        try:
            query_lower = query.lower()
            results = []
            
            for project in projects:
                score = 0
                match_details = []
                
                # Search in title
                if project.get('title', '').lower().find(query_lower) >= 0:
                    score += 3
                    match_details.append("Title match")
                
                # Search in transcript
                transcript = project.get('transcript', '')
                if transcript and query_lower in transcript.lower():
                    score += 2
                    match_details.append("Transcript match")
                    # Get context
                    idx = transcript.lower().find(query_lower)
                    context = transcript[max(0, idx-50):idx+50]
                    match_details.append(f"Context: {context}...")
                
                # Search in summary
                summary = project.get('summary', '')
                if summary and query_lower in summary.lower():
                    score += 2
                    match_details.append("Summary match")
                
                # Search in key points
                key_points = project.get('key_points', '')
                if key_points and query_lower in key_points.lower():
                    score += 2
                    match_details.append("Key points match")
                
                # Search in social content
                social = project.get('social_content', '')
                if social and query_lower in social.lower():
                    score += 1
                    match_details.append("Social content match")
                
                if score > 0:
                    results.append({
                        "project_id": project.get('id'),
                        "project_title": project.get('title'),
                        "score": score,
                        "matches": match_details,
                        "status": project.get('status'),
                        "created_at": project.get('created_at')
                    })
            
            # Sort by score
            results.sort(key=lambda x: x['score'], reverse=True)
            
            return {
                "success": True,
                "results": results,
                "total": len(results),
                "query": query
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def semantic_search(self, query: str, projects: List[Dict]) -> Dict[str, Any]:
        """
        Semantic search using simple embeddings (placeholder for advanced AI)
        
        Args:
            query: Search query
            projects: List of project data
        """
        try:
            # Simple keyword-based semantic matching
            # In production, use sentence-transformers or similar
            
            keywords = self._extract_keywords(query)
            
            results = []
            for project in projects:
                project_text = self._get_project_text(project)
                project_keywords = self._extract_keywords(project_text)
                
                # Calculate similarity based on keyword overlap
                overlap = len(keywords.intersection(project_keywords))
                similarity = overlap / len(keywords) if keywords else 0
                
                if similarity > 0:
                    results.append({
                        "project_id": project.get('id'),
                        "title": project.get('title'),
                        "similarity": similarity,
                        "status": project.get('status')
                    })
            
            results.sort(key=lambda x: x['similarity'], reverse=True)
            
            return {
                "success": True,
                "results": results,
                "total": len(results),
                "method": "semantic"
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    def _extract_keywords(self, text: str) -> set:
        """Extract keywords from text"""
        if not text:
            return set()
        
        # Simple keyword extraction
        words = text.lower().split()
        # Remove common stop words
        stop_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'is', 'are', 'was', 'were', 'be', 'been', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should'}
        keywords = {word for word in words if len(word) > 3 and word not in stop_words}
        return keywords
    
    def _get_project_text(self, project: Dict) -> str:
        """Extract all text from project"""
        text_parts = []
        for key in ['title', 'transcript', 'summary', 'key_points', 'social_content', 'blog_content']:
            if project.get(key):
                text_parts.append(str(project[key]))
        return ' '.join(text_parts)
    
    async def cache_search_index(self, projects: List[Dict]) -> Dict[str, Any]:
        """Cache search index for faster searches"""
        try:
            import hashlib
            timestamp = datetime.now().isoformat()
            cache_data = {
                "timestamp": timestamp,
                "projects": projects
            }
            
            # Create cache key
            cache_key = hashlib.md5(timestamp.encode()).hexdigest()
            cache_file = os.path.join(self.cache_dir, f"search_{cache_key}.json")
            
            with open(cache_file, 'w', encoding='utf-8') as f:
                json.dump(cache_data, f, indent=2)
            
            return {
                "success": True,
                "cache_file": cache_file,
                "cache_key": cache_key
            }
            
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
