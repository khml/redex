# Redex

軽量なミニ言語処理系ライブラリ（実験用）

セットアップ:

```bash
bundle install
bundle exec rake
```

## ドキュメント

- パーサ仕様: [docs/parser.md](docs/parser.md)

# Redex

軽量なミニ言語処理系（実験用）

Redex は空白区切りトークナイザと簡易パーサを提供する小さなライブラリです。学習・プロトタイプ用途を想定しており、入力文字列をトークン列に分解し、四則演算や
`let`/`const` などを含む簡易的な AST を生成します。

**主な特徴**

- シンプルなトークナイザ（整数リテラル、識別子、キーワード、演算子、括弧）
- 再帰下降パーサ（四則演算の優先順位、`let`/`const` 宣言対応）
- AST を返すパーサ API（`Redex::Parser.parse`）
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

リポジトリルートから直接 Ruby コマンドで試せます:

```bash
ruby -e "require './lib/redex/tokenizer'; require './lib/redex/parser'; p Redex::Tokenizer.tokenize('1 + 2'); p Redex::Parser.parse('1 + 2')"
```

出力（例）:

```
[#<struct Redex::Tokenizer::Token type=:number, value=1>, #<struct Redex::Tokenizer::Token type=:op, value="+">, #<struct Redex::Tokenizer::Token type=:number, value=2>]
{:type=>:binary, :op=>"+", :left=>{:type=>:number, :value=>1}, :right=>{:type=>:number, :value=>2}}
```

## ドキュメント

- 仕様（EBNF）: [docs/ebnf.md](docs/ebnf.md)
- パーサ設計: [docs/parser.md](docs/parser.md)
- トークナイザ設計: [docs/tokenizer.md](docs/tokenizer.md)
- アーキテクチャ: [docs/architecture.md](docs/architecture.md)
- 要件定義: [docs/requirements/requirements_specification.md](docs/requirements/requirements_specification.md)

