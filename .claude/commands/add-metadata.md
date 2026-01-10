---
description: gaikiyoku.fmのポッドキャストMP3ファイルにメタデータ（チャプター、タイトル、サマリー）を生成して追加
argument-hint: <エピソード番号>
---

# ポッドキャストメタデータ追加コマンド

ポッドキャストのトランスクリプトを分析し、チャプター、エピソードタイトル、サマリーを自動生成してgaikiyoku.fmのMP3ファイルに書き込みます。

## 使い方

```
/add-metadata <エピソード番号>
```

## 引数

- `エピソード番号`: エピソード番号（例: 64, 65）

コマンドは以下のgaikiyoku.fm固有のパスを使用します:
- MP3ファイル: `audio/gaikiyokufm-{4桁の番号}.mp3`
- トランスクリプトファイル: `audio/transcript/gaikiyokufm-{4桁の番号}.json`

## 実行手順

このコマンドが呼び出されたら、以下の手順に注意深く従ってください:

**⚠️ 重要: 一時ファイルや中間ファイルを一切作成しないこと**
- 全ての操作は元のMP3ファイル上でインプレースで行う必要があります
- "temp.mp3"、"{episode}_temp.mp3"、バックアップファイルなどのファイルを絶対に作成しないこと
- トランスクリプトへのアクセスにはReadツールを使用（ファイルコピーなし）
- MP3編集にはeyeD3 Python APIを使用してインプレース編集（書き込みにffmpegは使用しない）

### 0. プロジェクト設定

gaikiyoku.fm固有の設定を定義（このプロジェクトではハードコード）:

```bash
PROJECT_ROOT="/Users/shidetake/git/gaikiyokufm.github.io"
AUDIO_DIR="audio"
TRANSCRIPT_DIR="audio/transcript"
FILE_PREFIX="gaikiyokufm"
PADDING=4
```

以降の全ての手順では、これらの設定を使用してファイルパスを構築します。

### 1. 引数の解析と検証

位置パラメータからエピソード番号を抽出:
- `$1`: エピソード番号（数値）

エピソード番号を検証:
- 正の整数である必要があります
- 無効な場合、エラーを表示: "Invalid episode number. Please provide a numeric episode number (e.g., 65)"

### 2. ファイルパスの構築

ファイルパスを構築（エピソード番号を4桁にゼロパディング）:
```
mp3_file="${PROJECT_ROOT}/${AUDIO_DIR}/${FILE_PREFIX}-{episode_number_padded}.mp3"
json_file="${PROJECT_ROOT}/${TRANSCRIPT_DIR}/${FILE_PREFIX}-{episode_number_padded}.json"
```

例: エピソード65 → `/Users/shidetake/git/gaikiyokufm.github.io/audio/gaikiyokufm-0065.mp3` と `.../audio/transcript/gaikiyokufm-0065.json`

**⚠️ 重要: ファイル存在確認の方法**
- **Bashスクリプトで存在確認をしないこと** (`[ -f "$mp3_file" ]` などを使わない)
- **次のステップ（手順3の依存関係確認、手順4のffprobe）を直接実行すること**
- ファイルが存在しない場合、ffprobeやReadツールが自動的にエラーを返す
- エラーが発生した場合のみ、ユーザーにファイルパスとエピソード番号の確認を提案

### 3. 依存関係の確認

必要なツールが利用可能か確認:
```bash
command -v ffprobe >/dev/null 2>&1 || { echo "ffprobe not found. Please install: brew install ffmpeg"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "python3 not found"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found. Please install: brew install jq"; exit 1; }
```

### 4. 現在のMP3メタデータを読み込み

ffprobeを使用して音声の長さと現在のメタデータを取得:
```bash
ffprobe -v quiet -print_format json -show_format -show_chapters "{mp3_file}"
```

抽出:
- 秒単位の長さ: `format.duration`
- 現在のタイトル: `format.tags.title`
- 現在のコメント: `format.tags.comment`
- 既存のチャプター: `chapters[]`

ユーザーに表示:
```
Reading episode {episode_number}...
- MP3 file: {mp3_file}
- Duration: {duration_seconds}s ({minutes}:{seconds})
```

### 5. 参照エピソードを分析

参照エピソード（episode_number - 1, episode_number - 2, episode_number - 3）について:
- ゼロパディングを使用してファイルパスを構築
- 各参照MP3が ${PROJECT_ROOT}/${AUDIO_DIR}/ に存在するか確認
- 存在する場合、ffprobeを使用してメタデータを抽出

見つかった各参照エピソードから抽出:
- タイトル: `format.tags.title`
- チャプター: `tags.title` と `start_time` を持つ `chapters[]`
- サマリー: `format.tags.comment`

ユーザーに表示:
```
Analyzing reference episodes for style consistency...
- Episode {N-1}: "{title}" ({chapter_count} chapters)
- Episode {N-2}: "{title}" ({chapter_count} chapters)
- Episode {N-3}: "{title}" ({chapter_count} chapters)
```

参照エピソードが見つからない場合、警告を表示:
"No reference episodes found. Will generate metadata based on transcript only."

### 6. トランスクリプトを読み込み

Pythonスクリプトを使用してトランスクリプトJSONファイルを読み込み・処理:

```bash
python3 .claude/scripts/read_transcript.py "{json_file}"
```

スクリプトは以下のJSONを出力:
- `full_text`: 完全なトランスクリプトテキスト
- `sampled_segments`: 開始/終了時刻とテキストを持つ10個おきのセグメント
- `total_segments`: 総セグメント数

JSON出力を解析:
```bash
transcript_json=$(python3 .claude/scripts/read_transcript.py "{json_file}")
```

メタデータ生成に使用するためにJSON出力からデータを抽出:
- 全体的な内容分析のための全文
- チャプター境界検出のためのタイムスタンプ付きサンプルセグメント
- 参照用の総セグメント数

スクリプトが失敗した場合、エラーを表示:
"Failed to read transcript JSON. Please verify file format."

ユーザーに表示:
```
Reading transcript...
- Total segments: {total_segments}
- Sampled segments: {sampled_count} (every 10th)
```

### 7. AIでメタデータを生成

Claudeを使用してトランスクリプトを分析し、メタデータを生成します。以下のプロンプトを提供:

```
gaikiyoku.fmのエピソード{episode_number}のメタデータを生成するために、日本語ポッドキャストトランスクリプトを分析しています。

## エピソード情報
- エピソード番号: {episode_number}
- 長さ: {duration_seconds}秒 ({minutes}分)

## 参照エピソード（スタイルの一貫性のため）

{見つかった各参照エピソードについて:}
エピソード {ref_number}:
- タイトル: {ref_title}
- チャプター ({ref_chapter_count}):
  {各チャプターについて:}
  - {start_time_formatted} - {chapter_title}
- サマリー: {ref_summary}

## トランスクリプトセグメント（タイムスタンプ付き）

{開始/終了時刻とテキストを持つサンプルセグメント - これらのタイムスタンプを使用してトピックの移り変わりを特定}

形式例:
- 0.4s-3.54s: "こんにちは 外記録FMです"
- 922.78s-925.02s: "プログリッド3ヶ月"
- 1244.92s-1248.02s: "僕ひぐまというyoutuberにはまってます"

{ここにサンプルセグメントのリスト}

## 完全なトランスクリプトテキスト

{full_transcript_text}

## タスク

以下のルールに従ってこのエピソードのメタデータを生成してください:

### 1. エピソードタイトル
形式: "{episode_number}. {日本語の説明的なタイトル}"
- 話し合われた主要なトピック2-3個を捉える
- 参照エピソードのスタイルに従う
- 簡潔だが説明的に保つ
- 例: "64. Oasisと火災警報と松茸小屋"

### 2. チャプター
重要な要件:
- 上記のトランスクリプトセグメントのタイムスタンプを使用して、自然なトピックの移り変わりを特定
- 各トピックの切り替わりが発生する正確なセグメントタイムスタンプ（秒単位）を見つける
- start_msのためにそのタイムスタンプをミリ秒に変換（秒 × 1000）
- チャプター数はコンテンツから自然に導き出されるべき（~40分エピソードで通常3-5チャプター）
- チャプターを均等に配置したり、時間ベースの間隔を使用しないこと
- "オープニング" や "エンディング" チャプターは一切なし - これらは完全にスキップ
- 最初のチャプターは必ず0ms（00:00）から開始
- オープニングの雑談（天気、挨拶など）はスキップ - 最初のチャプタータイトルは実際の最初のトピックについてであるべき
- 各チャプターは明確なトピックまたは会話セグメントを表すべき
- チャプタータイトルは簡潔で説明的であるべき（参照エピソードのように）

### ランキングコンテンツ検出（特別処理）

**重要: このエピソードがランキング形式のコンテンツを含んでいるか分析してください。**

ランキングの指標:
- タイトルまたはトランスクリプト冒頭に "ランキング" の言及
- ランキング順位の連続的な言及: "3位", "2位", "1位"
- 複数の話者が各自の選択を発表
- "私の3位は", "僕の1位は", "〜さんの2位は" などのフレーズ

**ランキングコンテンツが検出された場合:**

ランキングのチャプター作成:
1. 言及された各ユニークなランキング項目ごとにチャプターを作成（最初の言及のみ）
2. **チャプタータイトル = アイテム名のみ**（順位なし、話者名なし、ラベルなし）
   - 例:
     - "茨城ゆるーム"
     - "ラカンの湯"
     - "前橋毎日サウナ"
   - 不可: "1位: ラカンの湯" ❌
   - 不可: "飯崎の1位: ラカンの湯" ❌
   - 不可: "番外編: アダム&イブ" ❌
3. アイテムが最初に紹介/命名されたタイムスタンプを使用
4. **重複処理**: 同じアイテムが複数回言及された場合（異なる話者/順位）、最初の言及時のみチャプター作成
5. **番外編の扱い**: "番外編" ラベルなし - アイテム名を直接使用
   - 単一アイテム: アイテム名のみ使用
   - 複数アイテム: "{item1}と{item2}" または別チャプター
6. 必要に応じてランキングチャプターと他の非ランキングトピックチャプターを混在可能
7. 典型的なランキングエピソード: 5-8個のユニークチャプター（ユニーク項目 + アウトロ）

**ランキングコンテンツでない場合:**
- 標準の3-5トピックベースチャプターを使用

ランキングが検出された場合はJSONで `"ranking_mode": true` を、そうでない場合は `false` を返してください。

形式: 以下を含むオブジェクトのJSON配列として返す:
- `start_ms`: ミリ秒単位の開始時刻（整数） - セグメントタイムスタンプから取得
- `title`: 日本語のチャプタータイトル（文字列）

最後のチャプターは {duration_ms} ミリ秒で終了すべきです。

実際のトピック移り変わりからのタイムスタンプを示す例:
[
  {"start_ms": 0, "title": "東京マラソン完走記"},
  {"start_ms": 922780, "title": "ラーメン店巡り"},
  {"start_ms": 1499000, "title": "次回の目標"}
]

### 3. サマリー
形式: スラッシュ区切りのキーワードで "について話しました。" で終了
- 話し合われた全ての主要なトピックをリスト
- "/" を区切り文字として使用
- 参照エピソードのスタイルに従う
- "について話しました。" で終了

例: "東京マラソン完走/ラーメン店巡り/次回の目標/トレーニング計画について話しました。"

## 出力形式

以下の正確な構造のJSONオブジェクトのみを返してください:
{
  "title": "65. タイトル",
  "ranking_mode": false,
  "chapters": [
    {"start_ms": 0, "title": "チャプター1"},
    {"start_ms": 600000, "title": "チャプター2"}
  ],
  "summary": "トピック1/トピック2/トピック3について話しました。"
}

重要な注意事項:
- ランキングコンテンツが検出された場合は "ranking_mode": true を、そうでない場合は false を設定
- ランキングエピソードの場合: チャプタータイトルはアイテム名のみ（例: "茨城ゆるーム", "ラカンの湯"）
  - 順位番号は不可: ❌ "1位: ラカンの湯"
  - 話者名は不可: ❌ "飯崎の1位: ラカンの湯"
  - アイテムのみ: ✅ "ラカンの湯"
- 非ランキングエピソードの場合: 通常通り説明的なトピックタイトルを使用

マークダウンコードブロック、説明、追加テキストは含めないでください - JSONオブジェクトのみ。
```

Claudeからの JSON レスポンスを解析します。

レスポンスを検証:
- `title`, `chapters`, `summary`, `ranking_mode` フィールドを持つこと
- `ranking_mode` はブール値（true または false）であること
- `chapters` は少なくとも2要素の配列であること
- 最初のチャプターは0から開始すること
- 全ての start_ms 値が有効な整数であること
- チャプターのタイムスタンプが昇順であること

検証が失敗した場合、詳細を含むエラーを表示します。

生成されたメタデータをユーザーに表示:
```
Generated metadata:

Title: {title}
Mode: {ranking_mode ? "Ranking-format" : "Standard"}

Chapters ({count}):
{For each chapter:}
- {start_time_formatted} - {title}

Summary:
{summary}
```

### 8. MP3にメタデータを適用

**⚠️ 重要: 中間ファイルなし - インプレース編集のみ**

eyeD3 APIを使用したPythonスクリプトで、全てのメタデータ（タイトル、サマリー、チャプター）を一度の操作で追加します。
Pythonスクリプトは必ずMP3ファイルをインプレース編集する必要があります。一時ファイルを一切作成しないでください。

```bash
# JSONからチャプター引数を構築
# 形式: "start_ms:title,start_ms:title,..."
chapters_arg=""
for i in "${!chapters[@]}"; do
  start_ms=$(echo "${chapters[$i]}" | jq -r '.start_ms')
  chapter_title=$(echo "${chapters[$i]}" | jq -r '.title')
  if [ -n "$chapters_arg" ]; then
    chapters_arg="${chapters_arg},"
  fi
  chapters_arg="${chapters_arg}${start_ms}:${chapter_title}"
done

# 全てのメタデータを追加するPythonスクリプトを呼び出し（インプレース、一時ファイルなし）
python3 .claude/scripts/add_podcast_metadata.py \
  "{mp3_file}" \
  "{title}" \
  "{summary}" \
  "${chapters_arg}"
```

スクリプトが成功したか確認:
- 終了コードが0の場合: 成功、全てのメタデータが適用された
- 失敗した場合: Pythonトレースバックと共にエラーを表示

表示:
```
Applying metadata to MP3...
✓ Title, summary, and chapters added successfully
```

**重要な注意事項:**
- ❌ 中間ファイルなし - temp.mp3、{episode}_temp.mp3、バックアップファイルを絶対に作成しない
- ✅ MP3ファイルのインプレース編集のみ
- ✅ 単一操作で全てのメタデータをアトミックに追加
- ✅ 全てにeyeD3 Python APIを使用（書き込みにffmpegは使用しない）
- ❌ ffmpeg -i input.mp3 output.mp3 を使用しない（中間ファイルを作成する）
- ❌ 編集前にファイルをコピーしない

### 9. 検証とレポート

ffprobeを使用してメタデータが書き込まれたことを検証:
```bash
ffprobe -v quiet -print_format json -show_format -show_chapters "{mp3_file}"
```

確認:
- タイトルが生成されたものと一致
- チャプター数が一致
- 最初のチャプターが0から開始
- コメント/サマリーが存在

最終サマリーを表示:
```
✓ Verification complete

Episode {episode_number} metadata has been added:
- Title: {title}
- {chapter_count} chapters created
- Summary keywords added

You can now play the MP3 to see chapters in your podcast player!
```

## エラーハンドリング

以下のエラーシナリオを適切に処理してください:

1. **ファイルが見つからない**
   - チェックした正確なパスを表示
   - エピソード番号を確認するよう提案

2. **無効なエピソード番号**
   - 例を表示: `/add-metadata 65`

3. **ffmpeg/ffprobeが見つからない**
   - macOS用のインストールコマンドを表示: `brew install ffmpeg`

4. **トランスクリプト解析エラー**
   - ファイルパスを表示
   - JSON構造を確認するよう提案

5. **AI生成エラー**
   - 失敗した内容（タイトル/チャプター/サマリー）を表示
   - デバッグ用にClaudeの生レスポンスを表示

6. **メタデータ書き込みエラー**
   - 元のファイルを保持
   - ffmpegのエラー出力を表示
   - ファイルのパーミッションを確認

7. **参照エピソードがない**
   - エラーではなく警告として扱う
   - 生成処理を続行

## 注意事項

- 常にゼロパディングした4桁のエピソード番号を使用（例: 0065、65ではない）
- ユーザーが進捗を把握できるよう、各ステップで進捗を表示
- トランスクリプトファイルは大きい場合がある（600KB+）ので適切に処理
- プロジェクト固有のパスはgaikiyoku.fm用にハードコード済み

## ⚠️ 重要: ファイル処理ルール

**絶対に中間ファイルを作成しないこと:**
- ❌ 一時MP3ファイルを作成してはいけない (temp.mp3, {episode}_temp.mp3, backup.mp3など)
- ❌ ffmpegで新しいMP3ファイルを作成してはいけない (ffmpeg -i input.mp3 output.mp3)
- ❌ 編集前にMP3ファイルをコピーしてはいけない
- ✅ eyeD3 Python APIでインプレース編集のみ使用すること
- ✅ トランスクリプトアクセスにはReadツールのみ使用（ファイル操作なし）
- ✅ 元のMP3ファイルをtag.save(mp3_file)で直接編集すること

インプレースでの元のMP3の読み書き以外のファイル作成をしようとしている場合は、停止してアプローチを再考すること。
