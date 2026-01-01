"""
Clean Translator Service - Handles translation with dependency management
"""
import os
import asyncio
import hashlib
from typing import Dict, Any, List, Optional

class TranslatorService:
    def __init__(self, cache_manager=None):
        self.supported_languages = {
            'en': 'English',
            'es': 'Spanish',
            'fr': 'French',
            'de': 'German',
            'it': 'Italian',
            'pt': 'Portuguese',
            'ru': 'Russian',
            'ja': 'Japanese',
            'ko': 'Korean',
            'zh': 'Chinese',
            'ar': 'Arabic'
        }
        self.cache_manager = cache_manager
    
    def _get_translation_cache_key(self, text: str, source_lang: str, target_lang: str) -> str:
        """Generate cache key for translation"""
        # Create a hash of the text for the cache key
        text_hash = hashlib.md5(text.encode('utf-8')).hexdigest()[:16]
        return f"translation:{source_lang}:{target_lang}:{text_hash}"
    
    async def get_available_languages(self) -> Dict[str, Any]:
        """Get list of available translation languages"""
        try:
            # Check if argostranslate is available
            try:
                import argostranslate.package
                import argostranslate.translate
                
                # Update package index
                argostranslate.package.update_package_index()
                available_packages = argostranslate.package.get_available_packages()
                
                # Extract unique language codes
                languages = set()
                for package in available_packages:
                    languages.add(package.from_code)
                    languages.add(package.to_code)
                
                return {
                    "success": True,
                    "languages": list(languages),
                    "source": "argostranslate"
                }
                
            except ImportError:
                # Fallback to static list
                return {
                    "success": True,
                    "languages": list(self.supported_languages.keys()),
                    "source": "static"
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def translate_text(self, text: str, target_lang: str, source_lang: str = "auto") -> Dict[str, Any]:
        """
        Translate text to target language (Non-blocking)
        
        Args:
            text: Text to translate
            target_lang: Target language code
            source_lang: Source language code (auto for detection)
        """
        try:
            # Detect language if auto is specified
            if source_lang == "auto":
                detected_lang = await self._detect_language(text)
                if detected_lang:
                    source_lang = detected_lang
                    print(f"🔍 Detected language: {source_lang}")
                else:
                    # Fallback to English if detection fails
                    source_lang = "en"
                    print(f"⚠️ Language detection failed, defaulting to English")
            
            # Check translation memory (L4 cache) first
            if self.cache_manager:
                cache_key = self._get_translation_cache_key(text, source_lang, target_lang)
                cached_translation = self.cache_manager.get("translation", cache_key)
                if cached_translation:
                    return {
                        "success": True,
                        "translated_text": cached_translation,
                        "source_lang": source_lang,
                        "target_lang": target_lang,
                        "cached": True
                    }
            
            # Try argostranslate first
            try:
                import argostranslate.package
                import argostranslate.translate
                
                # Get available packages (blocking call if network is involved or processing index)
                available_packages = await asyncio.to_thread(argostranslate.package.get_available_packages)
                package_to_install = None
                
                for package in available_packages:
                    if package.to_code == target_lang:
                        if source_lang == "auto" or package.from_code == source_lang:
                            package_to_install = package
                            break
                
                if package_to_install:
                    # Install if not already installed (blocking)
                    installed_packages = await asyncio.to_thread(argostranslate.package.get_installed_packages)
                    if not any(p.from_code == package_to_install.from_code and 
                              p.to_code == package_to_install.to_code 
                              for p in installed_packages):
                        download_path = await asyncio.to_thread(package_to_install.download)
                        await asyncio.to_thread(argostranslate.package.install_from_path, download_path)
                    
                    # Translate (blocking CPU task)
                    translated = await asyncio.to_thread(
                        argostranslate.translate.translate,
                        text, 
                        package_to_install.from_code, 
                        package_to_install.to_code
                    )
                    
                    # Store in translation memory (L4 cache)
                    if self.cache_manager:
                        cache_key = self._get_translation_cache_key(text, package_to_install.from_code, target_lang)
                        self.cache_manager.set("translation", cache_key, translated, level=4)
                    
                    return {
                        "success": True,
                        "translated_text": translated,
                        "source_lang": package_to_install.from_code,
                        "target_lang": package_to_install.to_code,
                        "cached": False
                    }
                else:
                    raise Exception(f"No translation package found for {source_lang} -> {target_lang}")
                    
            except ImportError:
                # Fallback to Google Translate API (requires googletrans)
                return await self._translate_fallback(text, target_lang)
                    
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
    
    async def _detect_language(self, text: str) -> Optional[str]:
        """
        Detect the language of the given text.
        Uses multiple methods with fallback.
        """
        # Method 1: Try langdetect library
        try:
            from langdetect import detect
            detected = await asyncio.to_thread(detect, text)
            # Map langdetect codes to our supported languages
            lang_map = {
                'en': 'en', 'es': 'es', 'fr': 'fr', 'de': 'de',
                'it': 'it', 'pt': 'pt', 'ru': 'ru', 'ja': 'ja',
                'ko': 'ko', 'zh-cn': 'zh', 'zh-tw': 'zh', 'ar': 'ar'
            }
            return lang_map.get(detected, detected)
        except ImportError:
            pass
        except Exception:
            pass
        
        # Method 2: Try polyglot library
        try:
            from polyglot.detect import Detector
            from polyglot.text import Text
            
            polyglot_text = await asyncio.to_thread(Text, text)
            detector = await asyncio.to_thread(Detector, polyglot_text)
            detected = detector.language.code
            return detected if detected in self.supported_languages else None
        except ImportError:
            pass
        except Exception:
            pass
        
        # Method 3: Simple heuristic based on character patterns
        try:
            # Check for Arabic characters
            if any('\u0600' <= c <= '\u06FF' for c in text):
                return 'ar'
            # Check for CJK characters (Chinese, Japanese, Korean)
            if any('\u4E00' <= c <= '\u9FFF' for c in text):
                # Distinguish between Japanese and Chinese
                if any('\u3040' <= c <= '\u309F' or '\u30A0' <= c <= '\u30FF' for c in text):
                    return 'ja'
                if any('\uAC00' <= c <= '\uD7AF' for c in text):
                    return 'ko'
                return 'zh'
            # Check for Cyrillic (Russian)
            if any('\u0400' <= c <= '\u04FF' for c in text):
                return 'ru'
        except Exception:
            pass
        
        return None
    
    async def _translate_fallback(self, text: str, target_lang: str) -> Dict[str, Any]:
        """Fallback translation using googletrans"""
        try:
            from googletrans import Translator
            
            translator = Translator()
            result = translator.translate(text, dest=target_lang)
            
            # Store in translation memory (L4 cache)
            if self.cache_manager and result.src != "unknown":
                cache_key = self._get_translation_cache_key(text, result.src, target_lang)
                self.cache_manager.set("translation", cache_key, result.text, level=4)
            
            return {
                "success": True,
                "translated_text": result.text,
                "source_lang": result.src,
                "target_lang": target_lang,
                "cached": False
            }
            
        except ImportError:
            # Final fallback: return original text
            return {
                "success": True,
                "translated_text": text,
                "source_lang": "unknown",
                "target_lang": target_lang,
                "note": "Translation library not available, returned original text"
            }
    
    async def install_language(self, from_code: str, to_code: str) -> Dict[str, Any]:
        """Install translation package for specific language pair"""
        try:
            import argostranslate.package
            
            argostranslate.package.update_package_index()
            available_packages = argostranslate.package.get_available_packages()
            
            package_to_install = None
            for package in available_packages:
                if package.from_code == from_code and package.to_code == to_code:
                    package_to_install = package
                    break
            
            if package_to_install:
                argostranslate.package.install_from_path(package_to_install.download())
                return {
                    "success": True,
                    "message": f"Installed {from_code} -> {to_code}"
                }
            else:
                return {
                    "success": False,
                    "error": f"No package found for {from_code} -> {to_code}"
                }
                
        except Exception as e:
            return {
                "success": False,
                "error": str(e),
                "error_type": type(e).__name__
            }
