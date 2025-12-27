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
