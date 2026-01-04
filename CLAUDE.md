# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

gaikiyoku.fm は、Jekyll で構築され GitHub Pages でホスティングされている日本語ポッドキャストサイトです。59以上のエピソードを配信しており、全エピソードに音声トランスクリプトと自動化されたプロダクションワークフローを備えています。

## 開発コマンド

### ローカル開発
```bash
# ローカルJekyllサーバーを起動
make local
# または直接:
bundle exec jekyll serve -I

# Dockerベースの開発
docker-compose up
```

### コンテンツ制作ワークフロー
```bash
# 新規エピソード投稿を作成（最新の音声ファイルから自動生成）
make post

# WAVをメタデータ付きMP3に変換
make mp3 ARG=episode.wav

# ステレオ音声をモノラルトラックに分割
make split ARG=episode.wav

# Whisperを使用してトランスクリプトを生成
make whisper

# トランスクリプトでAlgolia検索インデックスを更新
make algolia

# Twitter投稿コンテンツを生成
make twitter
```

## アーキテクチャ

### Jekyll設定
- **レイアウト**: `_layouts/` には `article.html`（エピソードページ）、`default.html`（ベース）、`search.html` が含まれます
- **投稿**: 各エピソードは `_posts/` 内のマークダウンファイルで、YAMLフロントマターを持ちます
- **出演者**: `_config.yml` で定義され、ホストプロフィール用のGravatar URLを持ちます
- **音声**: `audio/` ディレクトリ内のMP3ファイル、トランスクリプトは `audio/transcript/` にあります

### コンテンツ構造
- **エピソードテンプレート**: makefileで新規エピソード生成に使用される `template.md`
- **フロントマター変数**: `actor_ids`, `audio_file_path`, `audio_file_size`, `duration`, `description`, `title`
- **オーディオプレイヤー**: 埋め込み音声再生にMediaElement.jsを使用

### ビルドプロセス
makefileがポッドキャスト制作パイプライン全体を自動化:
1. 音声処理（WAV → ID3タグ付きMP3変換）
2. 音声ファイルからメタデータを抽出して投稿を生成
3. OpenAI Whisperを使用したトランスクリプト生成
4. Algoliaによる検索インデックス作成
5. ソーシャルメディアコンテンツ生成

### 主要なファイルパターン
- エピソード: `_posts/YYYY-MM-DD-{episode_number}.md`
- 音声: `audio/gaikiyokufm-{zero_padded_number}.mp3`
- トランスクリプト: `audio/transcript/gaikiyokufm-{zero_padded_number}.{format}`

### SCSS構造
- メインスタイルシート: `css/main.scss`
- `css/blocks/` 内のモジュール化されたブロック（articles, cards, headersなどのコンポーネント用）
- `css/_variables.scss` と `css/_mixins.scss` 内の変数とミックスイン

## 重要な注意事項
- 全ての音声ファイルにはffprobe/eyeD3経由で埋め込まれたメタデータ（タイトル、説明）が含まれます
- トランスクリプトは複数形式で生成されます（JSON, SRT, VTT, TXT, TSV）
- サイトは日本語の言語設定とタイムゾーン（Asia/Tokyo）を使用します
- Algolia検索統合には `_config.yml` 内のAPIキーが必要です
- Gitフックは `.githooks` ディレクトリで設定されています
