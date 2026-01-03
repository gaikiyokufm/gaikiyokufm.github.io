---
description: Generate and add metadata (chapters, title, summary) to podcast MP3 files for gaikiyoku.fm
argument-hint: <episode-number>
---

# Add Podcast Metadata Command

Analyzes a podcast transcript and automatically generates chapters, episode title, and summary, then writes them to the MP3 file for gaikiyoku.fm.

## Usage

```
/add-metadata <episode-number>
```

## Arguments

- `episode-number`: The episode number (e.g., 64, 65)

The command uses the following gaikiyoku.fm-specific paths:
- MP3 files: `audio/gaikiyokufm-{4-digit-number}.mp3`
- Transcript files: `audio/transcript/gaikiyokufm-{4-digit-number}.json`

## Execution Steps

When this command is invoked, follow these steps carefully:

**⚠️ CRITICAL: DO NOT CREATE ANY TEMPORARY OR INTERMEDIATE FILES**
- All operations MUST be in-place on the original MP3 file
- NEVER create files like "temp.mp3", "{episode}_temp.mp3", or any backup files
- Use Read tool for transcript access (no file copying)
- Use eyeD3 Python API for in-place MP3 editing (no ffmpeg for writing)

### 0. Project Configuration

Define gaikiyoku.fm-specific settings (these are hardcoded for this project):

```bash
PROJECT_ROOT="/Users/shidetake/git/gaikiyokufm.github.io"
AUDIO_DIR="audio"
TRANSCRIPT_DIR="audio/transcript"
FILE_PREFIX="gaikiyokufm"
PADDING=4
```

All subsequent steps use these settings to construct file paths.

### 1. Parse Arguments and Validate

Extract episode number from positional parameter:
- `$1`: episode number (numeric)

Validate episode number:
- Must be a positive integer
- If invalid, show error: "Invalid episode number. Please provide a numeric episode number (e.g., 65)"

### 2. Check File Existence

Construct file paths (zero-pad episode number to 4 digits):
```
mp3_file="${PROJECT_ROOT}/${AUDIO_DIR}/${FILE_PREFIX}-{episode_number_padded}.mp3"
json_file="${PROJECT_ROOT}/${TRANSCRIPT_DIR}/${FILE_PREFIX}-{episode_number_padded}.json"
```

Example: Episode 65 → `/Users/shidetake/git/gaikiyokufm.github.io/audio/gaikiyokufm-0065.mp3` and `.../audio/transcript/gaikiyokufm-0065.json`

Check if both files exist:
- If mp3 missing: "MP3 file not found: {mp3_file}"
- If json missing: "Transcript file not found: {json_file}"
- Suggest checking episode number

### 3. Verify Dependencies

Check if required tools are available:
```bash
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found. Please install: brew install ffmpeg"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found. Please install: brew install jq"; exit 1; }
```

### 4. Read Current MP3 Metadata

Use ffprobe to get audio duration and current metadata:
```bash
ffprobe -v quiet -print_format json -show_format -show_chapters "{mp3_file}"
```

Extract:
- Duration in seconds: `format.duration`
- Current title: `format.tags.title`
- Current comment: `format.tags.comment`
- Existing chapters: `chapters[]`

Display to user:
```
Reading episode {episode_number}...
- MP3 file: {mp3_file}
- Duration: {duration_seconds}s ({minutes}:{seconds})
```

### 5. Analyze Reference Episodes

For reference episodes (episode_number - 1, episode_number - 2, episode_number - 3):
- Construct file paths with zero-padding
- Check if each reference MP3 exists in ${PROJECT_ROOT}/${AUDIO_DIR}/
- If exists, use ffprobe to extract metadata

For each reference episode found, extract:
- Title: `format.tags.title`
- Chapters: `chapters[]` with `tags.title` and `start_time`
- Summary: `format.tags.comment`

Display to user:
```
Analyzing reference episodes for style consistency...
- Episode {N-1}: "{title}" ({chapter_count} chapters)
- Episode {N-2}: "{title}" ({chapter_count} chapters)
- Episode {N-3}: "{title}" ({chapter_count} chapters)
```

If no reference episodes found, show warning:
"No reference episodes found. Will generate metadata based on transcript only."

### 6. Read Transcript

Use the Python script to read and process the transcript JSON file:

```bash
python3 .claude/scripts/read_transcript.py "{json_file}"
```

The script outputs JSON with:
- `full_text`: Complete transcript text
- `sampled_segments`: Every 10th segment with start/end times and text
- `total_segments`: Total number of segments

Parse the JSON output:
```bash
transcript_json=$(python3 .claude/scripts/read_transcript.py "{json_file}")
```

Extract data from the JSON output for use in metadata generation:
- Full text for overall content analysis
- Sampled segments with timestamps for chapter boundary detection
- Total segment count for reference

If the script fails, show error:
"Failed to read transcript JSON. Please verify file format."

Display to user:
```
Reading transcript...
- Total segments: {total_segments}
- Sampled segments: {sampled_count} (every 10th)
```

### 7. Generate Metadata with AI

Now use Claude to analyze the transcript and generate metadata. Provide this prompt:

```
You are analyzing a Japanese podcast transcript to generate metadata for episode {episode_number} of gaikiyoku.fm.

## Episode Information
- Episode number: {episode_number}
- Duration: {duration_seconds} seconds ({minutes} minutes)

## Reference Episodes (for style consistency)

{For each reference episode found:}
Episode {ref_number}:
- Title: {ref_title}
- Chapters ({ref_chapter_count}):
  {For each chapter:}
  - {start_time_formatted} - {chapter_title}
- Summary: {ref_summary}

## Transcript Segments (with timestamps)

{Sampled segments with start/end times and text - use these timestamps to identify topic transitions}

Example format:
- 0.4s-3.54s: "こんにちは 外記録FMです"
- 922.78s-925.02s: "プログリッド3ヶ月"
- 1244.92s-1248.02s: "僕ひぐまというyoutuberにはまってます"

{List sampled segments here}

## Full Transcript Text

{full_transcript_text}

## Task

Generate metadata for this episode following these rules:

### 1. EPISODE TITLE
Format: "{episode_number}. {descriptive title in Japanese}"
- Capture 2-3 main topics discussed
- Follow the style of reference episodes
- Keep concise but descriptive
- Example: "64. Oasisと火災警報と松茸小屋"

### 2. CHAPTERS
CRITICAL REQUIREMENTS:
- Use the Transcript Segments timestamps above to identify natural topic transitions
- Find the EXACT segment timestamp (in seconds) where each topic shift occurs
- Convert that timestamp to milliseconds for start_ms (multiply seconds by 1000)
- Chapter count should naturally emerge from content (typically 3-5 chapters for ~40min episodes)
- DO NOT space chapters evenly or use time-based intervals
- NO "オープニング" or "エンディング" chapters - skip these entirely
- First chapter MUST start at 0ms (00:00)
- Skip opening chitchat (weather, greetings, etc.) - the first chapter title should be about the ACTUAL first topic
- Each chapter should represent a distinct topic or conversation segment
- Chapter titles should be concise and descriptive (like reference episodes)

Format: Return as JSON array of objects with:
- `start_ms`: Start time in milliseconds (integer) - taken from segment timestamp
- `title`: Chapter title in Japanese (string)

The last chapter should end at {duration_ms} milliseconds.

Example showing timestamps from actual topic transitions:
[
  {"start_ms": 0, "title": "東京マラソン完走記"},
  {"start_ms": 922780, "title": "ラーメン店巡り"},
  {"start_ms": 1499000, "title": "次回の目標"}
]

### 3. SUMMARY
Format: Slash-separated keywords ending with "について話しました。"
- List all major topics discussed
- Use "/" as separator
- Follow the style of reference episodes
- End with "について話しました。"

Example: "東京マラソン完走/ラーメン店巡り/次回の目標/トレーニング計画について話しました。"

## Output Format

Return ONLY a valid JSON object with this exact structure:
{
  "title": "65. タイトル",
  "chapters": [
    {"start_ms": 0, "title": "チャプター1"},
    {"start_ms": 600000, "title": "チャプター2"}
  ],
  "summary": "トピック1/トピック2/トピック3について話しました。"
}

Do not include any markdown code blocks, explanations, or extra text - ONLY the JSON object.
```

Parse the JSON response from Claude.

Validate the response:
- Has `title`, `chapters`, and `summary` fields
- `chapters` is an array with at least 2 elements
- First chapter starts at 0
- All start_ms values are valid integers
- Chapter timestamps are in ascending order

If validation fails, show error with details.

Display generated metadata to user:
```
Generated metadata:

Title: {title}

Chapters ({count}):
{For each chapter:}
- {start_time_formatted} - {title}

Summary:
{summary}
```

### 8. Apply Metadata to MP3

**⚠️ CRITICAL: NO INTERMEDIATE FILES - EDIT IN-PLACE ONLY**

Use Python script with eyeD3 API to add all metadata (title, summary, chapters) in one operation.
The Python script MUST edit the MP3 file in-place. DO NOT create any temporary files.

```bash
# Build chapters argument from JSON
# Format: "start_ms:title,start_ms:title,..."
chapters_arg=""
for i in "${!chapters[@]}"; do
  start_ms=$(echo "${chapters[$i]}" | jq -r '.start_ms')
  chapter_title=$(echo "${chapters[$i]}" | jq -r '.title')
  if [ -n "$chapters_arg" ]; then
    chapters_arg="${chapters_arg},"
  fi
  chapters_arg="${chapters_arg}${start_ms}:${chapter_title}"
done

# Call Python script to add all metadata (in-place, no temp files)
python3 .claude/scripts/add_podcast_metadata.py \
  "{mp3_file}" \
  "{title}" \
  "{summary}" \
  "${chapters_arg}"
```

Check if script succeeded:
- If exit code is 0: Success, all metadata applied
- If failed: Show error with Python traceback

Display:
```
Applying metadata to MP3...
✓ Title, summary, and chapters added successfully
```

**CRITICAL NOTES:**
- ❌ NO intermediate files - NEVER create temp.mp3, {episode}_temp.mp3, or any backup files
- ✅ In-place editing of MP3 file ONLY
- ✅ Single operation adds all metadata atomically
- ✅ Uses eyeD3 Python API for everything (no ffmpeg for writing)
- ❌ DO NOT use ffmpeg -i input.mp3 output.mp3 (creates intermediate file)
- ❌ DO NOT copy files before editing

### 9. Verify and Report

Use ffprobe to verify metadata was written:
```bash
ffprobe -v quiet -print_format json -show_format -show_chapters "{mp3_file}"
```

Check:
- Title matches what was generated
- Chapter count matches
- First chapter starts at 0
- Comment/summary is present

Display final summary:
```
✓ Verification complete

Episode {episode_number} metadata has been added:
- Title: {title}
- {chapter_count} chapters created
- Summary keywords added

You can now play the MP3 to see chapters in your podcast player!
```

## Error Handling

Handle these error scenarios gracefully:

1. **Missing Files**
   - Show exact path that was checked
   - Suggest verifying episode number

2. **Invalid Episode Number**
   - Show example: `/add-metadata 65`

3. **ffmpeg/ffprobe Not Found**
   - Show install command for macOS: `brew install ffmpeg`

4. **Transcript Parse Error**
   - Show file path
   - Suggest checking JSON structure

5. **AI Generation Error**
   - Show what failed (title/chapters/summary)
   - Display Claude's raw response for debugging

6. **Metadata Write Error**
   - Preserve original file
   - Show ffmpeg error output
   - Check file permissions

7. **No Reference Episodes**
   - Just a warning, not an error
   - Proceed with generation

## Notes

- Always use zero-padded 4-digit episode numbers (e.g., 0065, not 65)
- Display progress at each step so user knows what's happening
- The transcript file can be large (600KB+), handle appropriately
- Project-specific paths are hardcoded for gaikiyoku.fm

## ⚠️ CRITICAL FILE HANDLING RULES

**ABSOLUTELY NO INTERMEDIATE FILES:**
- ❌ NEVER create temporary MP3 files (temp.mp3, {episode}_temp.mp3, backup.mp3, etc.)
- ❌ NEVER use ffmpeg to create new MP3 files (ffmpeg -i input.mp3 output.mp3)
- ❌ NEVER copy the MP3 file before editing
- ✅ ONLY use eyeD3 Python API for in-place editing
- ✅ ONLY use Read tool to access transcript (no file operations)
- ✅ Edit the original MP3 file directly with tag.save(mp3_file)

If you find yourself about to create ANY file other than reading/writing the original MP3 in-place, STOP and reconsider your approach.
