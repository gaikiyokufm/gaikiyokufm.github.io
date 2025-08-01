# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Japanese podcast website (gaikiyoku.fm) built with Jekyll and hosted on GitHub Pages. The site features 59+ episodes with full audio transcripts and automated production workflows.

## Development Commands

### Local Development
```bash
# Start local Jekyll server
make local
# or directly:
bundle exec jekyll serve -I

# Docker-based development
docker-compose up
```

### Content Production Workflow
```bash
# Create new episode post (auto-generates from latest audio file)
make post

# Convert WAV to MP3 with metadata
make mp3 ARG=episode.wav

# Split stereo audio to mono tracks
make split ARG=episode.wav

# Generate transcripts using Whisper
make whisper

# Update Algolia search index with transcripts
make algolia

# Generate Twitter post content
make twitter
```

## Architecture

### Jekyll Configuration
- **Layouts**: `_layouts/` contains `article.html` (episode pages), `default.html` (base), `search.html`
- **Posts**: Each episode is a markdown file in `_posts/` with YAML frontmatter
- **Actors**: Defined in `_config.yml` with Gravatar URLs for host profiles
- **Audio**: MP3 files in `audio/` directory with transcripts in `audio/transcript/`

### Content Structure
- **Episode Template**: `template.md` used by makefile to generate new episodes
- **Frontmatter Variables**: `actor_ids`, `audio_file_path`, `audio_file_size`, `duration`, `description`, `title`
- **Audio Player**: Uses MediaElement.js for embedded audio playback

### Build Process
The makefile automates the entire podcast production pipeline:
1. Audio processing (WAV → MP3 conversion with ID3 tags)
2. Post generation with metadata extraction from audio files
3. Transcript generation using OpenAI Whisper
4. Search indexing with Algolia
5. Social media content generation

### Key File Patterns
- Episodes: `_posts/YYYY-MM-DD-{episode_number}.md`
- Audio: `audio/gaikiyokufm-{zero_padded_number}.mp3`
- Transcripts: `audio/transcript/gaikiyokufm-{zero_padded_number}.{format}`

### SCSS Structure
- Main stylesheet: `css/main.scss`
- Modular blocks in `css/blocks/` for components like articles, cards, headers
- Variables and mixins in `css/_variables.scss` and `css/_mixins.scss`

## Important Notes
- All audio files include metadata (title, description) embedded via ffprobe/eyeD3
- Transcripts are generated in multiple formats (JSON, SRT, VTT, TXT, TSV)
- The site uses Japanese language settings and timezone (Asia/Tokyo)
- Algolia search integration requires API keys in `_config.yml`
- Git hooks are configured via `.githooks` directory