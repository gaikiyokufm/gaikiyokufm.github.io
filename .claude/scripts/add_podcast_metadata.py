#!/usr/bin/env python3
"""Add podcast metadata (title, summary, chapters) to MP3 file using eyeD3."""
import sys
import subprocess
import json
from eyed3.id3.tag import Tag

def get_audio_duration_ms(mp3_file):
    """Get MP3 audio duration in milliseconds using ffprobe."""
    result = subprocess.run(
        ['ffprobe', '-v', 'quiet', '-print_format', 'json', '-show_format', mp3_file],
        capture_output=True, text=True
    )
    data = json.loads(result.stdout)
    duration_seconds = float(data['format']['duration'])
    return int(duration_seconds * 1000)

def main():
    if len(sys.argv) != 5:
        print("Usage: add_podcast_metadata.py <mp3_file> <title> <summary> <chapters>", file=sys.stderr)
        print("  chapters format: '0:Title1,922780:Title2,1244920:Title3'", file=sys.stderr)
        sys.exit(1)

    mp3_file = sys.argv[1]
    title = sys.argv[2]
    summary = sys.argv[3]
    chapters_arg = sys.argv[4]

    # Get audio duration in milliseconds
    audio_duration_ms = get_audio_duration_ms(mp3_file)

    # Parse MP3
    tag = Tag()
    tag.parse(mp3_file)

    # Set text metadata
    tag.title = title
    tag.comments.set(summary)
    tag.lyrics.set(summary)  # Add lyrics for Forecast duration checkbox

    # Clear existing chapters
    for chap in list(tag.chapters):
        tag.chapters.remove(chap.element_id)

    # Parse and add chapters
    chapters = []
    for chapter_def in chapters_arg.split(','):
        start_ms_str, chapter_title = chapter_def.split(':', 1)
        chapters.append((int(start_ms_str), chapter_title))

    # Add chapters with calculated end times using bytes element_id
    chapter_ids = []
    for i, (start_ms, chapter_title) in enumerate(chapters):
        end_ms = chapters[i+1][0] if i+1 < len(chapters) else audio_duration_ms
        # Use bytes for element_id to avoid TypeError
        element_id = f"chp{i}".encode('utf-8')
        # Set chapter with times, then set title via sub_frames
        chapter_frame = tag.chapters.set(element_id, (start_ms, end_ms))
        chapter_frame.title = chapter_title
        chapter_ids.append(element_id)

    # Add Table of Contents (CTOC) to link all chapters
    # This is what makes Forecast show the Duration checkbox as checked
    tag.table_of_contents.set(
        b'toc',
        child_ids=chapter_ids,
        description=u''
    )

    # Save in-place
    tag.save(mp3_file, version=(2, 4, 0))  # Use ID3v2.4
    print(f"✓ Added {len(chapters)} chapters and metadata to {mp3_file}")

if __name__ == "__main__":
    main()
