import argostranslate.package
import argostranslate.translate
import logging

logger = logging.getLogger(__name__)

def install_languages():
    """Install English to Spanish/French/German packages by default"""
    logger.info("Updating package index...")
    argostranslate.package.update_package_index()
    available_packages = argostranslate.package.get_available_packages()
    
    # Install English -> Spanish as default test
    package_to_install = next(
        filter(
            lambda x: x.from_code == "en" and x.to_code == "es", available_packages
        ), None
    )
    
    if package_to_install:
        logger.info(f"Installing {package_to_install}...")
        argostranslate.package.install_from_path(package_to_install.download())
        logger.info("Installation complete.")

def translate_text(text, from_code="en", to_code="es"):
    """Translate text using installed packages"""
    try:
        # Auto-install if needed (simplified for MVP)
        # In prod, check installed_packages first
        
        translation = argostranslate.translate.translate(text, from_code, to_code)
        return translation
    except Exception as e:
        logger.error(f"Translation error: {e}")
        return text

def translate_segments(segments, target_lang="es"):
    """Translate a list of transcript segments"""
    translated_segments = []
    for seg in segments:
        new_seg = seg.copy()
        new_seg['text'] = translate_text(seg['text'], "en", target_lang)
        translated_segments.append(new_seg)
    return translated_segments
