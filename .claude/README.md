# gaikiyoku.fm 用 Claude Code

このドキュメントは、gaikiyoku.fm プロジェクト固有のClaude Codeコマンドとワークフローについて説明します。

## 利用可能なコマンド

### `/add-metadata <エピソード番号>`

ポッドキャストMP3ファイルにメタデータ（チャプター、タイトル、サマリー）を自動生成して追加します。

**使い方:**
```
/add-metadata 65
```

**実行内容:**
1. MP3ファイルとトランスクリプトJSONを読み込み
2. スタイルの一貫性のために過去3エピソードを分析
3. AIを使用して以下を生成:
   - エピソードタイトル（例: "65. タイトル"）
   - チャプター（トピックの変化に基づいて、約10分に1つ）
   - サマリー（スラッシュ区切りのキーワード、"について話しました。"で終了）
4. ffmpegを使用してMP3ファイルにメタデータを書き込み

**必要要件:**
- MP3ファイルが存在すること: `audio/gaikiyokufm-{4桁の番号}.mp3`
- トランスクリプトJSONが存在すること: `audio/transcript/gaikiyokufm-{4桁の番号}.json`
- ffmpegとffprobeがインストールされていること: `brew install ffmpeg`

## 新規エピソードワークフロー

新しいエピソードを公開する際は、以下の手順に従ってください:

### 1. 基本メタデータ付きMP3を作成
```bash
make mp3 ARG=episode-66.wav
```

これによりMP3ファイルが作成され、基本メタデータ（アルバムアート、テンプレートタイトル）が追加されます。

### 2. トランスクリプトを生成
```bash
make whisper
```

これによりWhisperを使用してトランスクリプトJSONファイルが作成されます。

### 3. 詳細なメタデータを追加
```bash
make metadata
```

または直接:
```bash
claude
> /add-metadata 66
```

これによりトランスクリプトを分析し、詳細なメタデータ（チャプター、タイトル、サマリー）が追加されます。

### 4. 投稿を作成
```bash
make post
```

これによりMP3メタデータからJekyll投稿ファイルが作成されます。

### 5. Twitter投稿を作成
```bash
make twitter
```

これによりTwitter告知用のテキストが生成されます。

## 完全なワークフロー

```bash
# ステップ1: 音声をMP3に変換
make mp3 ARG=episode-66.wav

# ステップ2: トランスクリプトを生成
make whisper

# ステップ3: メタデータを追加
make metadata

# ステップ4: 投稿を作成
make post

# ステップ5: 確認とコミット
git status
git add .
git commit -m "Add episode 66"
```

## トラブルシューティング

### コマンドが見つかりません: claude

Claude Codeがインストールされ、PATHに含まれていることを確認してください。参照: https://claude.com/claude-code

### MP3ファイルが見つかりません

以下を確認してください:
1. エピソード番号が正しいこと
2. MP3ファイルが `audio/gaikiyokufm-{4桁}.mp3` に存在すること
3. 番号が4桁にゼロパディングされていること（例: 0066、66ではない）

### トランスクリプトファイルが見つかりません

トランスクリプトを生成するために、まず `make whisper` を実行してください。

### ffmpeg/ffprobeが見つかりません

ffmpegをインストール:
```bash
brew install ffmpeg
```

### メタデータ生成に失敗しました

Claude Codeの出力でエラーを確認してください。よくある問題:
- トランスクリプトJSONの形式が不正
- 参照エピソードが利用できない（最初の3エピソード）
- AIの応答が有効なJSONではない

問題を修正した後、コマンドを再実行できます。

## 設定

プロジェクト固有の設定は `.claude/settings.local.json` にあります:
- git、ffmpeg、ffprobeなどの権限
- フック設定（該当する場合）

ポッドキャスト固有のパスは `.claude/commands/add-metadata.md` にハードコードされています:
- プロジェクトルート: `/Users/shidetake/git/gaikiyokufm.github.io`
- 音声ディレクトリ: `audio`
- トランスクリプトディレクトリ: `audio/transcript`
- ファイルプレフィックス: `gaikiyokufm`
- ゼロパディング: 4桁

## 追加リソース

- [Claude Codeドキュメント](https://code.claude.com/docs)
- [makefile](../makefile) - ビルド自動化
- [CLAUDE.md](../CLAUDE.md) - 開発ガイド
