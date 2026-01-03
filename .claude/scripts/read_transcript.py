#!/usr/bin/env python3
import json
import sys

def main():
    if len(sys.argv) != 2:
        print("Usage: read_transcript.py <transcript_json_file>", file=sys.stderr)
        sys.exit(1)

    transcript_file = sys.argv[1]

    try:
        with open(transcript_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # Extract full text
        full_text = data.get('text', '')

        # Extract and sample segments (every 10th)
        all_segments = data.get('segments', [])
        sampled_segments = []
        for i in range(0, len(all_segments), 10):
            seg = all_segments[i]
            sampled_segments.append({
                'start': seg.get('start'),
                'end': seg.get('end'),
                'text': seg.get('text', '')
            })

        # Output as JSON
        result = {
            'full_text': full_text,
            'sampled_segments': sampled_segments,
            'total_segments': len(all_segments)
        }

        print(json.dumps(result, ensure_ascii=False, indent=2))

    except FileNotFoundError:
        print(f"Error: Transcript file not found: {transcript_file}", file=sys.stderr)
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in transcript file: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error reading transcript: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    main()
