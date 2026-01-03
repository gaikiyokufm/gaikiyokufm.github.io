# Claude Code for gaikiyoku.fm

This document describes Claude Code commands and workflows specific to the gaikiyoku.fm project.

## Available Commands

### `/podcast-metadata <episode-number>`

Automatically generates and adds metadata (chapters, title, summary) to podcast MP3 files.

**Usage:**
```
/podcast-metadata 65
```

**What it does:**
1. Reads the MP3 file and transcript JSON
2. Analyzes 3 previous episodes for style consistency
3. Uses AI to generate:
   - Episode title (e.g., "65. タイトル")
   - Chapters (roughly 1 per 10 minutes, based on topic shifts)
   - Summary (slash-separated keywords ending with "について話しました。")
4. Writes metadata to the MP3 file using ffmpeg

**Requirements:**
- MP3 file must exist: `audio/gaikiyokufm-{4-digit-number}.mp3`
- Transcript JSON must exist: `audio/transcript/gaikiyokufm-{4-digit-number}.json`
- ffmpeg and ffprobe must be installed: `brew install ffmpeg`

## New Episode Workflow

When publishing a new episode, follow these steps:

### 1. Create MP3 with Basic Metadata
```bash
make mp3 ARG=episode-66.wav
```

This creates the MP3 file and adds basic metadata (album art, template title).

### 2. Generate Transcript
```bash
make whisper
```

This uses Whisper to create the transcript JSON file.

### 3. Add Detailed Metadata
```bash
make metadata
```

or directly:
```bash
claude
> /podcast-metadata 66
```

This analyzes the transcript and adds detailed metadata (chapters, title, summary).

### 4. Create Post
```bash
make post
```

This creates the Jekyll post file from the MP3 metadata.

### 5. Create Twitter Post
```bash
make twitter
```

This generates text for the Twitter announcement.

## Complete Workflow

```bash
# Step 1: Convert audio to MP3
make mp3 ARG=episode-66.wav

# Step 2: Generate transcript
make whisper

# Step 3: Add metadata
make metadata

# Step 4: Create post
make post

# Step 5: Review and commit
git status
git add .
git commit -m "Add episode 66"
```

## Troubleshooting

### Command not found: claude

Make sure Claude Code is installed and in your PATH. See: https://claude.com/claude-code

### MP3 file not found

Check that:
1. The episode number is correct
2. The MP3 file exists in `audio/gaikiyokufm-{4-digit}.mp3`
3. The number is zero-padded to 4 digits (e.g., 0066, not 66)

### Transcript file not found

Make sure you ran `make whisper` first to generate the transcript.

### ffmpeg/ffprobe not found

Install ffmpeg:
```bash
brew install ffmpeg
```

### Metadata generation failed

Check the Claude Code output for errors. Common issues:
- Transcript JSON is malformed
- No reference episodes available (first 3 episodes)
- AI response was not valid JSON

You can retry the command after fixing the issue.

## Settings

Project-specific settings are in `.claude/settings.local.json`:
- Permissions for git, ffmpeg, ffprobe, etc.
- Hooks configuration (if any)

Podcast-specific paths are hardcoded in `.claude/commands/podcast-metadata.md`:
- Project root: `/Users/shidetake/git/gaikiyokufm.github.io`
- Audio directory: `audio`
- Transcript directory: `audio/transcript`
- File prefix: `gaikiyokufm`
- Zero-padding: 4 digits

## Additional Resources

- [Claude Code Documentation](https://code.claude.com/docs)
- [makefile](../makefile) - Build automation
- [CLAUDE.md](../CLAUDE.md) - Development guide
