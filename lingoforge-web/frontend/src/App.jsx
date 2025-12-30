import React, { useState, useEffect } from 'react';
import NeomorphicButton from './components/NeomorphicButton';
import GlassPanel from './components/GlassPanel';
import ParticleBackground from './components/ParticleBackground';
import apiClient from './services/api';

/**
 * LingoForge Studio - Main Application
 * Specs502: Cinematic dark gradient neomorphic UI with particle effects
 */
function App() {
  const [activeTab, setActiveTab] = useState('dashboard');
  const [projects, setProjects] = useState([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [currentProject, setCurrentProject] = useState(null);
  const [urlInput, setUrlInput] = useState('');
  const [quality, setQuality] = useState('best');
  const [isPlaylist, setIsPlaylist] = useState(false);
  const [status, setStatus] = useState('');
  const [cacheStats, setCacheStats] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);

  // Features tab state
  const [selectedProjectId, setSelectedProjectId] = useState(null);
  const [targetLang, setTargetLang] = useState('fr');
  const [selectedVoice, setSelectedVoice] = useState('en_female');
  const [featureStatus, setFeatureStatus] = useState('');
  const [translationResult, setTranslationResult] = useState(null);
  const [ttsResult, setTtsResult] = useState(null);

  // Dynamic language/voice lists
  const [availableLanguages, setAvailableLanguages] = useState([]);
  const [availableVoices, setAvailableVoices] = useState([]);

  // File manager state
  const [files, setFiles] = useState([]);
  const [fileStats, setFileStats] = useState({ total_size_mb: 0, total_files: 0 });

  // Load projects on mount and poll for updates
  useEffect(() => {
    loadProjects();
    loadCacheStats();
    loadLanguagesAndVoices();

    // Live monitoring: poll every 3 seconds
    const interval = setInterval(() => {
      loadProjects();
    }, 3000);

    return () => clearInterval(interval);
  }, []);

  const loadProjects = async () => {
    try {
      const response = await apiClient.getProjects();
      setProjects(response.projects || []);
    } catch (error) {
      console.error('Failed to load projects:', error);
      setProjects([]);
    }
  };

  const loadCacheStats = async () => {
    try {
      const response = await apiClient.getCacheStats();
      setCacheStats(response);
    } catch (error) {
      console.error('Failed to load cache stats:', error);
      setCacheStats(null);
    }
  };

  const loadLanguagesAndVoices = async () => {
    try {
      const [langResp, voiceResp] = await Promise.all([
        apiClient.getLanguages(),
        apiClient.getVoices()
      ]);
      setAvailableLanguages(langResp.languages || []);
      setAvailableVoices(voiceResp.voices || []);
    } catch (error) {
      console.error('Failed to load languages/voices:', error);
      // Fallback to static lists
      setAvailableLanguages([
        { code: 'en', name: 'English' },
        { code: 'fr', name: 'French' },
        { code: 'ar', name: 'Arabic' },
        { code: 'es', name: 'Spanish' },
        { code: 'de', name: 'German' },
        { code: 'it', name: 'Italian' },
        { code: 'pt', name: 'Portuguese' },
        { code: 'ru', name: 'Russian' },
        { code: 'ja', name: 'Japanese' },
        { code: 'ko', name: 'Korean' },
        { code: 'zh', name: 'Chinese' }
      ]);
      setAvailableVoices([
        { id: 'en_female', name: 'English Female', language: 'en' },
        { id: 'en_male', name: 'English Male', language: 'en' },
        { id: 'fr_female', name: 'French Female', language: 'fr' },
        { id: 'fr_male', name: 'French Male', language: 'fr' },
        { id: 'ar_female', name: 'Arabic Female', language: 'ar' },
        { id: 'ar_male', name: 'Arabic Male', language: 'ar' },
        { id: 'es_female', name: 'Spanish Female', language: 'es' },
        { id: 'es_male', name: 'Spanish Male', language: 'es' },
        { id: 'de_female', name: 'German Female', language: 'de' },
        { id: 'de_male', name: 'German Male', language: 'de' }
      ]);
    }
  };

  const handleCreateProject = async () => {
    if (!urlInput.trim()) {
      setStatus('Please enter a valid URL');
      return;
    }

    setIsProcessing(true);
    setStatus('Creating project...');
    setCurrentProject(null);
    try {
      const response = await apiClient.createProject(urlInput, quality, isPlaylist);
      const projectId = response.project_id || response.id;
      setStatus(response.message || `Project created: ${projectId}`);
      setUrlInput('');

      // Poll for completion
      if (projectId) {
        pollProjectStatus(projectId);
      } else {
        setStatus('Error: Project ID not returned');
        setIsProcessing(false);
      }
    } catch (error) {
      setStatus(`Error: ${error.message}`);
      setIsProcessing(false);
    }
  };

  const pollProjectStatus = async (projectId) => {
    if (!projectId) {
      console.error('Invalid project ID for polling');
      setIsProcessing(false);
      return;
    }

    const interval = setInterval(async () => {
      try {
        const response = await apiClient.getProject(projectId);
        // API returns { success: true, project: {...} }
        const project = response.project || response;
        setCurrentProject(project);

        if (project.status === 'completed') {
          setStatus('✅ Project completed successfully!');
          clearInterval(interval);
          setIsProcessing(false);
          await loadProjects();
        } else if (project.status === 'failed') {
          setStatus('❌ Project failed');
          clearInterval(interval);
          setIsProcessing(false);
        } else {
          setStatus(`⏳ ${project.status}...`);
        }
      } catch (error) {
        console.error('Polling error:', error);
        clearInterval(interval);
        setIsProcessing(false);
      }
    }, 2000);
  };

  const handleSearch = async () => {
    if (!searchQuery.trim()) return;

    try {
      const response = await apiClient.searchTranscripts(searchQuery);
      setSearchResults(response.results || []);
    } catch (error) {
      console.error('Search failed:', error);
      setSearchResults([]);
    }
  };

  const handleExport = async (projectId, format) => {
    try {
      setStatus(`⏳ Exporting project ${projectId} as ${format}...`);
      const data = await apiClient.exportProject(projectId, format);

      if (!data.success) {
        throw new Error(data.error || 'Export failed');
      }

      // Create download
      const blob = new Blob([data.content], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = data.filename;
      document.body.appendChild(a); // Recommended for some browsers
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      setStatus(`✅ Project exported: ${data.filename}${data.local_path ? ` (Saved to: ${data.local_path})` : ''}`);

      // Auto-clear success message after 8 seconds
      setTimeout(() => setStatus(''), 8000);
    } catch (error) {
      console.error('Export failed:', error);
      setStatus(`❌ Export failed: ${error.message}`);
    }
  };

  const handleExportBatch = async (playlistId) => {
    if (!playlistId) return;
    try {
      setStatus(`⏳ Exporting playlist batch...`);
      const data = await apiClient.exportBatch(playlistId);

      if (!data.success) {
        throw new Error(data.error || 'Batch export failed');
      }

      // Create download
      const blob = new Blob([data.content], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = data.filename;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);

      setStatus(`✅ Playlist batch exported: ${data.filename}${data.local_path ? ` (Saved to: ${data.local_path})` : ''}`);
      setTimeout(() => setStatus(''), 10000);
    } catch (error) {
      console.error('Batch export failed:', error);
      setStatus(`❌ Batch export failed: ${error.message}`);
    }
  };

  const handleClearCache = async () => {
    try {
      await apiClient.clearCache();
      await loadCacheStats();
      setFeatureStatus('✅ Cache cleared successfully');
      setTimeout(() => setFeatureStatus(''), 3000);
    } catch (error) {
      setFeatureStatus('❌ Failed to clear cache');
    }
  };

  const handleTranslate = async () => {
    if (!selectedProjectId) {
      setFeatureStatus('⚠️ Please select a project first');
      return;
    }

    setFeatureStatus('⏳ Translating...');
    setTranslationResult(null);
    try {
      const response = await apiClient.translateProjectNew(selectedProjectId, targetLang);
      if (response.success) {
        setTranslationResult(response);
        setFeatureStatus(`✅ Translation complete (${response.source_lang} → ${response.target_lang})`);
      } else {
        setFeatureStatus(`❌ Translation failed: ${response.error || 'Unknown error'}`);
      }
    } catch (error) {
      console.error('Translation error:', error);
      setFeatureStatus(`❌ Translation failed: ${error.message}`);
    }
  };

  const handleGenerateTTS = async () => {
    if (!selectedProjectId) {
      setFeatureStatus('⚠️ Please select a project first');
      return;
    }

    setFeatureStatus('⏳ Generating audio...');
    setTtsResult(null);
    try {
      const response = await apiClient.generateProjectTTS(selectedProjectId, selectedVoice);
      if (response.success) {
        setTtsResult(response);
        setFeatureStatus(`✅ Audio generated: ${response.filename}`);
      } else {
        setFeatureStatus(`❌ TTS failed: ${response.error || 'Unknown error'}`);
      }
    } catch (error) {
      console.error('TTS error:', error);
      setFeatureStatus(`❌ TTS failed: ${error.message}`);
    }
  };

  const loadFiles = async () => {
    try {
      const response = await apiClient.getFiles();
      setFiles(response.files || []);
      setFileStats({
        total_size_mb: response.total_size_mb || 0,
        total_files: response.total_files || 0,
        total_size_gb: response.total_size_gb || 0
      });
    } catch (error) {
      console.error('Failed to load files:', error);
    }
  };

  const handleDeleteFile = async (directory, filename) => {
    try {
      await apiClient.deleteFile(directory, filename);
      setFeatureStatus(`✅ Deleted: ${filename}`);
      loadFiles(); // Refresh list
      setTimeout(() => setFeatureStatus(''), 3000);
    } catch (error) {
      setFeatureStatus(`❌ Failed to delete: ${error.message}`);
    }
  };

  const handleCleanupAll = async () => {
    if (!window.confirm('Delete ALL files from downloads and cache? This cannot be undone!')) {
      return;
    }
    try {
      const response = await apiClient.cleanupAllFiles();
      setFeatureStatus(`✅ ${response.message}`);
      loadFiles();
      setTimeout(() => setFeatureStatus(''), 5000);
    } catch (error) {
      setFeatureStatus(`❌ Cleanup failed: ${error.message}`);
    }
  };

  const handleExportTranslation = async () => {
    if (!selectedProjectId) {
      setFeatureStatus('⚠️ Please select a project first');
      return;
    }
    try {
      const response = await apiClient.exportTranslation(selectedProjectId);
      if (response.success) {
        // Create download
        const blob = new Blob([response.content], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = response.filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        setFeatureStatus(`✅ Exported: ${response.filename}`);
        setTimeout(() => setFeatureStatus(''), 5000);
      }
    } catch (error) {
      setFeatureStatus(`❌ Export failed: ${error.message}`);
    }
  };

  const completedProjects = projects.filter(p => p.status === 'completed');

  // Tab Components
  const renderDashboard = () => (
    <div className="space-y-6">
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-lf-primary to-lf-secondary bg-clip-text text-transparent">
          🎬 New Project
        </h2>

        <div className="space-y-4">
          <input
            type="text"
            value={urlInput}
            onChange={(e) => setUrlInput(e.target.value)}
            placeholder="Paste YouTube URL here..."
            className="w-full px-4 py-3 bg-lf-surface/50 backdrop-blur rounded-xl border border-white/10 text-white placeholder-white/30 focus:outline-none focus:border-lf-primary transition-all"
          />

          <div className="flex gap-4 flex-wrap">
            <select
              value={quality}
              onChange={(e) => setQuality(e.target.value)}
              className="px-4 py-2 bg-lf-surface/50 backdrop-blur rounded-xl border border-white/10 text-white focus:outline-none focus:border-lf-primary"
            >
              <option value="best">Best Quality</option>
              <option value="1080p">1080p</option>
              <option value="720p">720p</option>
              <option value="480p">480p</option>
            </select>

            <label className="flex items-center gap-2 cursor-pointer">
              <input
                type="checkbox"
                checked={isPlaylist}
                onChange={(e) => setIsPlaylist(e.target.checked)}
                className="w-5 h-5 accent-lf-primary"
              />
              <span className="text-white/80">Playlist</span>
            </label>
          </div>

          <NeomorphicButton
            onClick={handleCreateProject}
            disabled={isProcessing}
            variant="primary"
            size="large"
            className="w-full"
          >
            {isProcessing ? '⏳ Processing...' : '🚀 Start Processing'}
          </NeomorphicButton>
        </div>
      </GlassPanel>

      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-lf-success to-emerald-400 bg-clip-text text-transparent">
          📊 Projects
        </h2>

        {projects.length === 0 ? (
          <div className="text-center text-white/50 py-8">
            No projects yet. Create your first project above!
          </div>
        ) : (
          <div className="space-y-3 max-h-96 overflow-y-auto">
            {projects.map((project) => (
              <div
                key={project.id}
                className="p-4 bg-lf-surface/30 backdrop-blur rounded-xl border border-white/5 hover:border-lf-primary/50 transition-all group"
              >
                <div className="flex justify-between items-start gap-4">
                  <div className="flex-1">
                    <div className="font-semibold text-white/90">
                      {project.title || `Project #${project.id}`}
                    </div>
                    <div className="text-xs text-white/50 mt-1">
                      {project.url}
                    </div>

                    {/* Progress Bar */}
                    {['downloading', 'transcribing', 'processing', 'translating', 'dubbing'].includes(project.status) && (
                      <div className="mt-3">
                        <div className="flex justify-between text-[10px] text-white/70 mb-1">
                          <span>{project.status === 'downloading' ? 'Downloading...' :
                            project.status === 'transcribing' ? 'Transcribing...' :
                              project.status === 'translating' ? 'Translating...' :
                                project.status === 'dubbing' ? 'Generating Audio...' :
                                  'Processing...'}</span>
                          <span>{project.progress || 0}%</span>
                        </div>
                        <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
                          <div
                            className="h-full bg-gradient-to-r from-lf-primary to-lf-secondary transition-all duration-300 ease-out"
                            style={{ width: `${project.progress || 0}%` }}
                          />
                        </div>
                      </div>
                    )}

                    <div className="text-xs mt-2 flex flex-col gap-1">
                      {!['downloading', 'transcribing', 'processing', 'translating', 'dubbing'].includes(project.status) && (
                        <span className={`px-2 py-1 rounded self-start ${project.status === 'completed' ? 'bg-lf-success/20 text-lf-success' :
                          project.status === 'failed' ? 'bg-lf-error/20 text-lf-error' :
                            'bg-lf-warning/20 text-lf-warning'
                          }`}>
                          {project.status}
                        </span>
                      )}
                      {project.status === 'failed' && project.error_message && (
                        <span className="text-lf-error/70 italic text-[10px]">
                          {project.error_message}
                        </span>
                      )}
                    </div>
                  </div>

                  <div className="flex gap-2 opacity-0 group-hover:opacity-100 transition-opacity">
                    <NeomorphicButton
                      size="small"
                      variant="glass"
                      onClick={() => handleExport(project.id, 'txt')}
                    >
                      TXT
                    </NeomorphicButton>
                    <NeomorphicButton
                      size="small"
                      variant="glass"
                      onClick={() => handleExport(project.id, 'srt')}
                    >
                      SRT
                    </NeomorphicButton>
                    {project.playlist_id && (
                      <NeomorphicButton
                        size="small"
                        variant="primary"
                        onClick={() => handleExportBatch(project.playlist_id)}
                      >
                        📦 Batch
                      </NeomorphicButton>
                    )}
                    <NeomorphicButton
                      size="small"
                      variant="outline"
                      onClick={async () => {
                        await apiClient.deleteProject(project.id);
                        await loadProjects();
                      }}
                    >
                      🗑️
                    </NeomorphicButton>
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </GlassPanel>
    </div>
  );

  const renderFeatures = () => (
    <div className="space-y-6">
      {/* Status Display */}
      {featureStatus && (
        <div className={`p-4 rounded-xl backdrop-blur ${featureStatus.includes('❌') ? 'bg-red-500/20 text-red-300' : featureStatus.includes('⏳') ? 'bg-lf-warning/20 text-lf-warning animate-pulse' : 'bg-lf-success/20 text-lf-success'}`}>
          {featureStatus}
        </div>
      )}

      {/* Project Selector */}
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-lf-secondary to-purple-400 bg-clip-text text-transparent">
          🎯 Select Project
        </h2>
        <select
          value={selectedProjectId || ''}
          onChange={(e) => setSelectedProjectId(e.target.value ? parseInt(e.target.value) : null)}
          className="w-full px-4 py-3 bg-lf-surface/50 backdrop-blur rounded-xl border border-white/10 text-white focus:outline-none focus:border-lf-primary"
        >
          <option value="">-- Select a completed project --</option>
          {completedProjects.map((project) => (
            <option key={project.id} value={project.id}>
              {project.title || `Project #${project.id}`} ({project.duration ? `${Math.floor(project.duration / 60)}min` : 'N/A'})
            </option>
          ))}
        </select>
        {completedProjects.length === 0 && (
          <p className="text-white/50 text-sm mt-2">No completed projects available. Process a video first from the Dashboard.</p>
        )}
      </GlassPanel>

      {/* Translation Panel */}
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-lf-primary to-blue-400 bg-clip-text text-transparent">
          🌐 Translation
        </h2>
        <p className="text-sm text-white/70 mb-4">
          Translate transcripts from any language to French, Arabic, or English
        </p>

        <div className="flex gap-4 flex-wrap items-end">
          <div className="flex-1 min-w-[200px]">
            <label className="block text-white/60 text-sm mb-2">Target Language</label>
            <select
              value={targetLang}
              onChange={(e) => setTargetLang(e.target.value)}
              className="w-full px-4 py-3 bg-lf-surface/50 backdrop-blur rounded-xl border border-white/10 text-white focus:outline-none focus:border-lf-primary"
            >
              {availableLanguages.length > 0 ? (
                availableLanguages.map(lang => (
                  <option key={lang.code} value={lang.code}>
                    {lang.code === 'en' && '🇬🇧 '}
                    {lang.code === 'fr' && '🇫🇷 '}
                    {lang.code === 'ar' && '🇸🇦 '}
                    {lang.code === 'es' && '🇪🇸 '}
                    {lang.code === 'de' && '🇩🇪 '}
                    {lang.code === 'it' && '🇮🇹 '}
                    {lang.code === 'pt' && '🇵🇹 '}
                    {lang.code === 'ru' && '🇷🇺 '}
                    {lang.code === 'ja' && '🇯🇵 '}
                    {lang.code === 'ko' && '🇰🇷 '}
                    {lang.code === 'zh' && '🇨🇳 '}
                    {lang.name} ({lang.code.toUpperCase()})
                  </option>
                ))
              ) : (
                <>
                  <option value="fr">🇫🇷 French (FR)</option>
                  <option value="ar">🇸🇦 Arabic (AR)</option>
                  <option value="en">🇬🇧 English (EN)</option>
                  <option value="es">🇪🇸 Spanish (ES)</option>
                  <option value="de">🇩🇪 German (DE)</option>
                </>
              )}
            </select>
          </div>
          <NeomorphicButton
            onClick={handleTranslate}
            variant="primary"
            size="medium"
            disabled={!selectedProjectId}
          >
            🔄 Translate
          </NeomorphicButton>
        </div>

        {translationResult && (
          <div className="mt-4 p-4 bg-lf-surface/30 rounded-xl border border-white/5">
            <div className="text-sm text-white/60 mb-2">
              Translation ({translationResult.source_lang} → {translationResult.target_lang})
            </div>
            <div className="text-white/90 max-h-48 overflow-y-auto text-sm leading-relaxed">
              {translationResult.translated_text?.substring(0, 500)}
              {translationResult.translated_text?.length > 500 && '...'}
            </div>
          </div>
        )}
      </GlassPanel>

      {/* TTS Panel */}
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-lf-success to-emerald-400 bg-clip-text text-transparent">
          🗣️ Text-to-Speech Dubbing
        </h2>
        <p className="text-sm text-white/70 mb-4">
          Generate audio voiceovers using Edge-TTS voices
        </p>

        <div className="flex gap-4 flex-wrap items-end">
          <div className="flex-1 min-w-[200px]">
            <label className="block text-white/60 text-sm mb-2">Voice</label>
            <select
              value={selectedVoice}
              onChange={(e) => setSelectedVoice(e.target.value)}
              className="w-full px-4 py-3 bg-lf-surface/50 backdrop-blur rounded-xl border border-white/10 text-white focus:outline-none focus:border-lf-primary"
            >
              {availableVoices.length > 0 ? (
                availableVoices.map(voice => (
                  <option key={voice.id} value={voice.id}>
                    {voice.name}
                  </option>
                ))
              ) : (
                <>
                  <option value="en_female">🇬🇧 English - Female</option>
                  <option value="en_male">🇬🇧 English - Male</option>
                  <option value="fr_female">🇫🇷 French - Female</option>
                  <option value="fr_male">🇫🇷 French - Male</option>
                  <option value="ar_female">🇸🇦 Arabic - Female</option>
                  <option value="ar_male">🇸🇦 Arabic - Male</option>
                  <option value="es_female">🇪🇸 Spanish - Female</option>
                  <option value="es_male">🇪🇸 Spanish - Male</option>
                  <option value="de_female">🇩🇪 German - Female</option>
                  <option value="de_male">🇩🇪 German - Male</option>
                </>
              )}
            </select>
          </div>
          <NeomorphicButton
            onClick={handleGenerateTTS}
            variant="success"
            size="medium"
            disabled={!selectedProjectId}
          >
            🎙️ Generate Audio
          </NeomorphicButton>
        </div>

        {ttsResult && (
          <div className="mt-4 p-4 bg-lf-surface/30 rounded-xl border border-white/5">
            <div className="text-sm text-white/60 mb-2">Generated Audio</div>
            <div className="flex items-center gap-4">
              <span className="text-white/90">{ttsResult.filename}</span>
              <span className="text-xs text-white/50">({(ttsResult.file_size / 1024).toFixed(1)} KB)</span>
              <a
                href={`${import.meta.env.VITE_API_URL || 'http://localhost:8000'}${ttsResult.download_url}`}
                target="_blank"
                rel="noopener noreferrer"
                className="text-lf-primary hover:text-lf-secondary transition-colors"
              >
                ⬇️ Download
              </a>
            </div>
          </div>
        )}
      </GlassPanel>

      {/* Cache Panel */}
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-lf-warning to-orange-400 bg-clip-text text-transparent">
          📥 Cache Management
        </h2>
        <p className="text-sm text-white/70 mb-4">
          4-Level Cache: L1 RAM (2GB) • L2 Disk (50GB) • L3 Model (VRAM) • L4 Translation Memory
        </p>

        {cacheStats && (
          <div className="grid grid-cols-3 gap-4 mb-4">
            <div className="p-3 bg-lf-surface/30 rounded-xl text-center">
              <div className="text-xl font-bold text-lf-primary">{cacheStats.l1?.entries || 0}</div>
              <div className="text-xs text-white/50">L1 RAM</div>
            </div>
            <div className="p-3 bg-lf-surface/30 rounded-xl text-center">
              <div className="text-xl font-bold text-lf-secondary">{cacheStats.l2?.entries || 0}</div>
              <div className="text-xs text-white/50">L2 Disk</div>
            </div>
            <div className="p-3 bg-lf-surface/30 rounded-xl text-center">
              <div className="text-xl font-bold text-lf-success">{cacheStats.l4?.entries || 0}</div>
              <div className="text-xs text-white/50">L4 Memory</div>
            </div>
          </div>
        )}

        <div className="flex gap-3">
          <NeomorphicButton
            size="small"
            variant="outline"
            onClick={handleClearCache}
          >
            🗑️ Clear Cache
          </NeomorphicButton>
          <NeomorphicButton
            size="small"
            variant="glass"
            onClick={loadCacheStats}
          >
            🔄 Refresh Stats
          </NeomorphicButton>
        </div>
      </GlassPanel>

      {/* File Manager Panel */}
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-teal-400 to-cyan-500 bg-clip-text text-transparent">
          📂 File Manager
        </h2>

        <div className="mb-4 flex justify-between items-center text-sm text-white/70">
          <div>
            Total: {fileStats.total_files} files • {fileStats.total_size_mb.toFixed(2)} MB
            {fileStats.total_size_gb > 1 && ` (${fileStats.total_size_gb.toFixed(2)} GB)`}
          </div>
          <div className="flex gap-2">
            <button
              onClick={loadFiles}
              className="px-3 py-1 bg-white/10 rounded-lg hover:bg-white/20 transition-colors"
            >
              Reload
            </button>
            <button
              onClick={handleCleanupAll}
              className="px-3 py-1 bg-red-500/20 text-red-300 rounded-lg hover:bg-red-500/30 transition-colors border border-red-500/30"
            >
              Cleanup All
            </button>
          </div>
        </div>

        {files.length > 0 ? (
          <div className="bg-lf-surface/30 rounded-xl overflow-hidden border border-white/5 max-h-60 overflow-y-auto">
            <table className="w-full text-sm text-left">
              <thead className="bg-white/5 text-white/60">
                <tr>
                  <th className="p-3">File</th>
                  <th className="p-3 text-right">Size</th>
                  <th className="p-3 text-right">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-white/5">
                {files.map((file) => (
                  <tr key={file.path} className="hover:bg-white/5 transition-colors">
                    <td className="p-3 whitespace-nowrap overflow-hidden text-ellipsis max-w-xs">
                      <span className={`inline-block w-2 h-2 rounded-full mr-2 ${file.directory === 'downloads' ? 'bg-blue-400' : 'bg-orange-400'}`}></span>
                      {file.name}
                    </td>
                    <td className="p-3 text-right text-white/70">
                      {file.size_mb > 1024
                        ? `${(file.size_mb / 1024).toFixed(2)} GB`
                        : `${file.size_mb} MB`}
                    </td>
                    <td className="p-3 text-right">
                      <button
                        onClick={() => handleDeleteFile(file.directory, file.name)}
                        className="text-red-400 hover:text-red-300 transition-colors"
                      >
                        Delete
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <div className="text-center py-8 text-white/50 bg-lf-surface/20 rounded-xl">
            No files found in downloads or cache
            <div className="mt-2">
              <button onClick={loadFiles} className="text-lf-primary underline">Refresh List</button>
            </div>
          </div>
        )}
      </GlassPanel>

      {/* Translation Export Panel */}
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-blue-400 to-indigo-500 bg-clip-text text-transparent">
          📤 Export Translation
        </h2>
        <p className="text-sm text-white/70 mb-4">
          Download the latest translation for the selected project
        </p>

        <div className="flex gap-4 items-center">
          <div className="flex-1">
            <div className="text-sm text-white/50 mb-1">Current Project</div>
            <div className={`text-lg font-medium truncate ${selectedProjectId ? 'text-white' : 'text-white/30'}`}>
              {selectedProjectId
                ? projects.find(p => p.id === selectedProjectId)?.title || `Project #${selectedProjectId}`
                : 'No project selected'}
            </div>
          </div>
          <NeomorphicButton
            onClick={handleExportTranslation}
            disabled={!selectedProjectId}
            variant="primary"
          >
            Download Translation (.txt)
          </NeomorphicButton>
        </div>
      </GlassPanel>
    </div>
  );

  const renderSearch = () => (
    <div className="space-y-6">
      <GlassPanel padding="large">
        <h2 className="text-2xl font-bold mb-4 bg-gradient-to-r from-lf-warning to-orange-400 bg-clip-text text-transparent">
          🔍 Search Transcripts
        </h2>

        <div className="flex gap-3 mb-4">
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search across all transcripts..."
            className="flex-1 px-4 py-3 bg-lf-surface/50 backdrop-blur rounded-xl border border-white/10 text-white placeholder-white/30 focus:outline-none focus:border-lf-warning"
            onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
          />
          <NeomorphicButton
            onClick={handleSearch}
            variant="warning"
            size="medium"
          >
            Search
          </NeomorphicButton>
        </div>

        {searchResults.length > 0 && (
          <div className="space-y-3 max-h-96 overflow-y-auto">
            {searchResults.map((result, idx) => (
              <div key={idx} className="p-4 bg-lf-surface/30 rounded-xl border border-white/5">
                <div className="font-semibold text-white/90 mb-1">
                  {result.title}
                </div>
                {result.matches && result.matches.length > 0 && (
                  <div className="text-sm text-white/70 italic mb-1">
                    {result.matches[0]}{result.matches.length > 1 ? ` (+${result.matches.length - 1} more)` : ''}
                  </div>
                )}
                <div className="text-xs text-white/50">
                  Score: {result.score}
                </div>
              </div>
            ))}
          </div>
        )}
      </GlassPanel>
    </div>
  );

  const tabs = [
    { id: 'dashboard', label: 'Dashboard', icon: '🎬' },
    { id: 'features', label: 'Features', icon: '✨' },
    { id: 'search', label: 'Search', icon: '🔍' },
  ];

  return (
    <div className="min-h-screen bg-gradient-to-br from-lf-bg-dark via-lf-bg-mid to-lf-bg-light relative overflow-hidden">
      {/* Particle Background */}
      <ParticleBackground active={isProcessing} density={isProcessing ? 'high' : 'low'} color="primary" />

      {/* Main Content */}
      <div className="relative z-10 container mx-auto px-4 py-8 max-w-7xl">
        {/* Header */}
        <header className="mb-8 text-center">
          <h1 className="text-5xl font-bold mb-2 bg-gradient-to-r from-lf-primary via-lf-secondary to-lf-primary bg-clip-text text-transparent animate-gradient-x">
            LingoForge Studio
          </h1>
          <p className="text-white/60 text-lg">
            Cinematic-grade video localization • 100% Free Tools
          </p>
        </header>

        {/* Navigation Tabs */}
        <div className="flex justify-center gap-3 mb-8 flex-wrap">
          {tabs.map((tab) => (
            <NeomorphicButton
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              variant={activeTab === tab.id ? 'primary' : 'glass'}
              size="medium"
              className="min-w-[120px]"
            >
              <span className="mr-2">{tab.icon}</span>
              {tab.label}
            </NeomorphicButton>
          ))}
        </div>

        {/* Tab Content */}
        <div className="animate-fade-in">
          {activeTab === 'dashboard' && renderDashboard()}
          {activeTab === 'features' && renderFeatures()}
          {activeTab === 'search' && renderSearch()}
        </div>

        {/* Footer */}
        <footer className="mt-12 text-center text-white/40 text-sm">
          <p>⚡ Powered by 100% Free Tools • Specs502 Compliant</p>
          <p className="mt-2">
            <span className="text-lf-primary">YouTube</span> •{" "}
            <span className="text-lf-secondary">Whisper</span> •{" "}
            <span className="text-lf-success">Argos Translate</span> •{" "}
            <span className="text-lf-warning">Edge TTS</span>
          </p>
        </footer>
      </div>

      {/* Floating Status Notification */}
      {status && (
        <div className="fixed bottom-8 left-1/2 -translate-x-1/2 z-[60] animate-slide-up">
          <GlassPanel className={`px-6 py-4 flex items-center gap-4 ${status.includes('❌') || status.includes('Error')
            ? 'border-lf-error/50 bg-lf-error/10'
            : 'border-lf-primary/50 bg-lf-primary/10'
            }`}>
            <span className="text-xl">
              {status.includes('✅') ? '✨' :
                status.includes('❌') || status.includes('Error') ? '⚠️' :
                  status.includes('⏳') ? '⚙️' : '🔔'}
            </span>
            <div className="flex flex-col">
              <span className={`font-medium ${status.includes('❌') || status.includes('Error') ? 'text-lf-error' : 'text-lf-primary'
                }`}>
                {status}
              </span>
              {currentProject?.status === 'failed' && currentProject?.error_message && (
                <span className="text-xs text-lf-error/70 italic mt-1">
                  {currentProject.error_message}
                </span>
              )}
            </div>
            <button
              onClick={() => setStatus('')}
              className="ml-4 p-1 hover:bg-white/10 rounded-full transition-colors text-white/50"
            >
              ✕
            </button>
          </GlassPanel>
        </div>
      )}

      {/* Processing Overlay */}
      {isProcessing && (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
          <GlassPanel className="text-center p-8">
            <div className="text-4xl mb-4 animate-pulse">⏳</div>
            <div className="text-xl font-bold mb-2">Processing...</div>
            <div className="text-white/70">{status}</div>
          </GlassPanel>
        </div>
      )}
    </div>
  );
}

export default App;
