# Redex

軽量なミニ言語処理系（実験用）

Redex は空白区切りトークナイザと簡易パーサを提供する小さなライブラリです。学習・プロトタイプ用途を想定しており、入力文字列をトークン列に分解し、四則演算や
`let`/`const` などを含む簡易的な AST を生成・評価します。

**主な特徴**

- シンプルなトークナイザ（整数リテラル、識別子、キーワード、演算子、括弧）
- 再帰下降パーサ（四則演算の優先順位、`let`/`const` 宣言対応）
- AST 評価器（変数/定数の管理、const 不変性チェック）
- 外部 Ruby コードとの統合（`context`, `ruby_resolver`）
- 詳細な評価結果（結果値、環境、出所情報、エラー情報）
- テストスイート（RSpec）を含む開発向けリポジトリ構成

**必要環境**

- Ruby 3.x
- Bundler

## セットアップ

まず依存をインストールします:

```bash
bundle install
```

テストの実行例:

```bash
bundle exec rspec
# または
bundle exec rake
```

## 簡単な使い方

### 基本的な式の評価

```ruby
require './lib/redex'

# 基本的な算術式
result = Redex::Interpreter.evaluate('1 + 2 * 3')
puts result[:result]  # => 7

# 括弧を使った式
result = Redex::Interpreter.evaluate('(1 + 2) * 3')
puts result[:result]  # => 9

# 変数定義
result = Redex::Interpreter.evaluate('let x = 10')
puts result[:result]  # => 10
puts result[:env][:x]  # => 10

# 定数定義
result = Redex::Interpreter.evaluate('const pi = 3')
puts result[:result]  # => 3
```

### context を使った評価

外部から初期値を提供できます:

```ruby
result = Redex::Interpreter.evaluate(
  'x + y',
  context: { 'x' => 5, 'y' => 3 }
)
puts result[:result]  # => 8
puts result[:provenance][:x]  # => "context"
puts result[:provenance][:y]  # => "context"
```

### ruby_resolver による動的解決

未解決の識別子を Ruby コードで解決できます:

```ruby
resolver = ->(name, ctx) do
  case name
  when 'current_time' then Time.now.to_i
  when 'random' then rand(100)
  else nil
  end
end

result = Redex::Interpreter.evaluate(
  'current_time + 1',
  ruby_resolver: resolver
)
puts result[:result]  # => (現在時刻のUNIXタイムスタンプ + 1)
puts result[:provenance][:current_time]  # => "ruby_resolver"
```

### 低レベル API の使用

トークナイザとパーサを直接使用することもできます:

```ruby
require './lib/redex/tokenizer'
require './lib/redex/parser'
require './lib/redex/evaluator'

# トークン化
tokens = Redex::Tokenizer.tokenize('1 + 2')
# => [#<struct Token type=:number, value=1>, ...]

# パース
ast = Redex::Parser.parse('1 + 2')
# => {:type=>:binary, :op=>"+", :left=>{...}, :right=>{...}}

# 評価
result = Redex::Evaluator.evaluate(ast)
puts result[:result]  # => 3
```

### 複数行ソースの扱い

`Redex::Interpreter.evaluate` は複数行のソースを受け取れます。各行は独立した文（statement）として上から順に評価され、最終行の評価結果が `:result` に返されます。

- 各行は通常改行（"\n"）で区切られますが、最終行の末尾改行は必須ではありません。
- 空行（改行のみの行）は無視されます。
- 既存の単一行インターフェースとは互換性があり、単一行（改行を含まない）の入力は従来どおり動作します。

例:

```ruby
src = "let a = 1\nlet b = 2\na + b\n"
res = Redex::Interpreter.evaluate(src)
puts res[:result] # => 3
```

## ドキュメント

### プロジェクトドキュメント

- 仕様（EBNF）: [docs/ebnf.md](docs/ebnf.md)
- パーサ設計: [docs/parser.md](docs/parser.md)
- トークナイザ設計: [docs/tokenizer.md](docs/tokenizer.md)
- 評価器設計: [docs/evaluator.md](docs/evaluator.md)
- アーキテクチャ: [docs/architecture.md](docs/architecture.md)
- 要件定義: [docs/requirements/requirements_specification.md](docs/requirements/requirements_specification.md)

### API ドキュメント（YARD）

YARD を使用して API ドキュメントを生成できます:

```bash
# YARD をインストール（初回のみ）
gem install yard

# ドキュメント生成
yard doc

# ドキュメントサーバーを起動
yard server
```

生成されたドキュメントは `doc/` ディレクトリに出力されます。ブラウザで `http://localhost:8808` にアクセスして閲覧できます。

## サンプルアプリケーション

`examples/` ディレクトリには、Redex を実際のアプリケーションで活用する例が含まれています。

### 1. CLI 電卓アプリ (`cli_calculator.rb`)

対話型の計算機アプリケーション。標準入力、コマンドライン引数、パイプ入力に対応しています。

```bash
# 対話モード（REPL）
ruby examples/cli_calculator.rb

# コマンドライン引数で評価
ruby examples/cli_calculator.rb "1 + 2 * 3"

# パイプ入力
echo "let x = 10\nx * 2" | ruby examples/cli_calculator.rb
```

機能:
- 履歴表示 (`history` コマンド)
- 環境リセット (`clear` コマンド)
- ヘルプ表示 (`help` コマンド)
- 変数・定数の永続化（セッション内）

### 2. context と ruby_resolver の活用例 (`context_and_resolver.rb`)

外部データや動的な値を Redex と連携する方法を示すサンプル集。

```bash
ruby examples/context_and_resolver.rb
```

含まれる例:
- context を使った外部データの注入
- ruby_resolver による動的値の解決（現在時刻、ランダム値など）
- context と ruby_resolver の併用
- 解決の優先順位の確認
- 実用的なユースケース（設定ファイルの式評価）

### 3. Sinatra Web API (`sinatra_demo.rb`)

HTTP API として Redex を公開する例。JSON で式を受け取り、評価結果を JSON で返します。

```bash
# Sinatra のインストール（初回のみ）
gem install sinatra

# サーバー起動
ruby examples/sinatra_demo.rb
```

使用例:

```bash
# 単一式の評価
curl -X POST http://localhost:4567/evaluate \
  -H "Content-Type: application/json" \
  -d '{"expression": "1 + 2 * 3"}'

# context を使った評価
curl -X POST http://localhost:4567/evaluate \
  -H "Content-Type: application/json" \
  -d '{"expression": "x + y", "context": {"x": 10, "y": 5}}'

# バッチ評価
curl -X POST http://localhost:4567/evaluate/batch \
  -H "Content-Type: application/json" \
  -d '{"expressions": ["1 + 1", "2 * 3", "10 / 2"]}'
```

エンドポイント:
- `GET /` - API 情報
- `GET /health` - ヘルスチェック
- `POST /evaluate` - 式の評価
- `POST /evaluate/batch` - バッチ評価

**セキュリティ警告**: このサンプルは教育目的です。本番環境では以下の対策が必要です:
- 入力サイズの制限（実装済み）
- レート制限
- タイムアウト設定
- HTTPS の使用
- 認証・認可の実装

### 4. Rake タスク統合 (`rake_task.rb`)

ビルドプロセスで設定値を式で計算する例。

```bash
# Rakefile に require して使用
# require_relative 'examples/rake_task'

# または直接実行
bundle exec rake -f examples/rake_task.rb config:generate
bundle exec rake -f examples/rake_task.rb config:validate
bundle exec rake -f examples/rake_task.rb config:from_env
```

ユースケース:
- ビルド時に設定ファイルを動的に生成
- 環境変数から設定値を計算
- デプロイ前の設定値の検証

タスク:
- `config:generate` - システム情報から設定ファイルを生成
- `config:validate` - 設定式の妥当性を検証
- `config:show` - 現在の設定値を表示
- `config:from_env` - 環境変数から設定値を計算

### サンプルの動作確認

各サンプルには対応する spec ファイルがあり、動作確認ができます:

```bash
# 全サンプルのテストを実行
bundle exec rspec spec/examples_spec.rb
```
