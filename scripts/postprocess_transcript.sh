#!/bin/bash
# Whisper トランスクリプトの後処理スクリプト
# 使用法: ./scripts/postprocess_transcript.sh <basename>
# 例: ./scripts/postprocess_transcript.sh audio/transcript/gaikiyokufm-0067

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
REPLACEMENTS_FILE="$REPO_ROOT/whisper_replacements.tsv"

if [ $# -lt 1 ]; then
    echo "使用法: $0 <basename>"
    echo "例: $0 audio/transcript/gaikiyokufm-0067"
    exit 1
fi

BASENAME="$1"

if [ ! -f "$REPLACEMENTS_FILE" ]; then
    echo "警告: 置換ルールファイルが見つかりません: $REPLACEMENTS_FILE"
    exit 0
fi

# 置換を実行する関数
apply_replacements() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return
    fi

    local temp_file=$(mktemp)
    cp "$file" "$temp_file"

    while IFS=$'\t' read -r search replace; do
        # コメント行と空行をスキップ
        [[ "$search" =~ ^#.*$ ]] && continue
        [[ -z "$search" ]] && continue

        # sed でエスケープが必要な文字を処理
        search_escaped=$(printf '%s\n' "$search" | sed 's/[[\.*^$()+?{|]/\\&/g')
        replace_escaped=$(printf '%s\n' "$replace" | sed 's/[&/\]/\\&/g')

        sed -i '' "s/${search_escaped}/${replace_escaped}/g" "$temp_file"
    done < "$REPLACEMENTS_FILE"

    mv "$temp_file" "$file"
    echo "処理完了: $file"
}

# JSONファイルに対して置換を実行
apply_replacements "${BASENAME}.json"
