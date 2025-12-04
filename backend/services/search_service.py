# backend/services/search_service.py
# Semantic search using sentence-transformers (lightweight, no FAISS needed for small datasets)

import logging
from typing import List, Dict, Any
import re

logger = logging.getLogger(__name__)

# Lazy load the model to avoid slow startup
_model = None
_embeddings_cache = {}

def get_model():
    global _model
    if _model is None:
        try:
            from sentence_transformers import SentenceTransformer
            _model = SentenceTransformer('all-MiniLM-L6-v2')  # Small, fast model
            logger.info("Loaded sentence-transformers model")
        except ImportError:
            logger.warning("sentence-transformers not installed, using keyword search fallback")
            return None
    return _model

def compute_embedding(text: str):
    """Compute embedding for a piece of text."""
    model = get_model()
    if model is None:
        return None
    return model.encode(text, convert_to_numpy=True)

def cosine_similarity(a, b):
    """Compute cosine similarity between two vectors."""
    import numpy as np
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def semantic_search(query: str, documents: List[Dict[str, Any]], top_k: int = 10) -> List[Dict[str, Any]]:
    """
    Search documents semantically.
    Each document should have 'id', 'text', and optionally 'title'.
    Returns documents sorted by relevance with 'score' field added.
    """
    model = get_model()
    
    if model is None:
        # Fallback to keyword search
        return keyword_search(query, documents, top_k)
    
    # Compute query embedding
    query_embedding = model.encode(query, convert_to_numpy=True)
    
    results = []
    for doc in documents:
        text = doc.get('text', '')
        doc_id = doc.get('id')
        
        # Use cached embedding or compute new one
        cache_key = f"{doc_id}_{hash(text[:100])}"
        if cache_key in _embeddings_cache:
            doc_embedding = _embeddings_cache[cache_key]
        else:
            doc_embedding = model.encode(text, convert_to_numpy=True)
            _embeddings_cache[cache_key] = doc_embedding
        
        score = float(cosine_similarity(query_embedding, doc_embedding))
        results.append({**doc, 'score': score})
    
    # Sort by score descending
    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:top_k]

def keyword_search(query: str, documents: List[Dict[str, Any]], top_k: int = 10) -> List[Dict[str, Any]]:
    """Fallback keyword search when sentence-transformers is not available."""
    query_terms = set(query.lower().split())
    
    results = []
    for doc in documents:
        text = doc.get('text', '').lower()
        title = doc.get('title', '').lower()
        
        # Count matching terms
        matches = sum(1 for term in query_terms if term in text or term in title)
        score = matches / len(query_terms) if query_terms else 0
        
        if score > 0:
            results.append({**doc, 'score': score})
    
    results.sort(key=lambda x: x['score'], reverse=True)
    return results[:top_k]

def search_transcripts(query: str, transcripts: List[Dict], top_k: int = 10) -> List[Dict]:
    """
    Search across multiple transcripts.
    Each transcript should have 'project_id', 'title', 'segments'.
    Returns matching segments with project context.
    """
    # Flatten segments for searching
    documents = []
    for t in transcripts:
        project_id = t.get('project_id')
        title = t.get('title', f'Project {project_id}')
        segments = t.get('segments', [])
        
        for i, seg in enumerate(segments):
            text = seg.get('text', '')
            if len(text) > 20:  # Skip very short segments
                documents.append({
                    'id': f"{project_id}_{i}",
                    'project_id': project_id,
                    'title': title,
                    'segment_index': i,
                    'text': text,
                    'start': seg.get('start', 0),
                    'end': seg.get('end', 0),
                })
    
    return semantic_search(query, documents, top_k)
