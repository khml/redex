# Redex パーサ設計・使用ドキュメント

この文書は `lib/redex/parser.rb` に実装されたパーサの設計仕様、使用例、AST 形式、および制限事項をまとめます。

## 概要
- 入力: 文字列（ソース）またはトークン配列
- 出力: Ruby ハッシュで表現された AST ノード（トップレベルは単一の文/式）
- 例外: 構文エラー時は `Redex::Parser::ParseError` を発生させる

## サポートする構文
- 数値リテラル（例: 42）
- 識別子（例: x, total）
- 二項演算: `+`, `-`, `*`, `/`（通常の優先度・左結合）
- `let` / `const` 宣言（簡易な代入宣言構文）
- 括弧によるグルーピング（例: `(1 + 2) * 3`）

## Parser クラス API 仕様

この節は `lib/redex/parser.rb` に実装されている `Redex::Parser` クラスの公開 API とその振る舞いを明確に定義します。

- クラスメソッド

  - `Redex::Parser.parse(source)`
    - 引数: `source` — `String`（ソースコード）または `Array<Token>`（トークン列）
    - 動作: `String` の場合は内部で `Redex::Tokenizer.tokenize` を呼びトークナイズし、パーサインスタンスを生成して `parse_program` を実行します。
    - 返値: AST を表す `Hash`（トップレベルノード）
    - 例外: 構文エラー時は `Redex::Parser::ParseError` を raise


# パーサ（Parser）

## 概要

`Redex::Parser` は `lib/redex/parser.rb` に実装された再帰下降パーサです。入力は文字列（ソース）または `Tokenizer` の返すトークン配列で、出力は Ruby のハッシュで表現された AST（トップレベルは単一の文/式）です。構文エラーは `Redex::Parser::ParseError` を発生させます。

## API

- `Redex::Parser.parse(source)`
  - 引数: `source` — `String` または `Array<Token>`（`Token` は `Tokenizer` の `Struct`）
  - 戻り値: `Hash`（トップレベルの AST ノード）
  - 例外: 構文エラー時に `Redex::Parser::ParseError` を raise
  - 動作: `String` の場合は内部で `Redex::Tokenizer.tokenize` を呼んでトークナイズ後パースします。

### インスタンスメソッド（主なもの・振る舞い）

- `initialize(tokens)` — トークン列を受け取り内部状態を初期化
- `current` -> `Token | nil` — 現在のトークンを参照する
- `eat(expected_type = nil)` -> `Token` — 期待トークンを検査して消費、失敗時は `ParseError`
- `parse_program` -> `Hash` — トップレベルの文/式を返す
- `parse_statement`, `parse_let` — `let`/`const` 宣言のパース
- `parse_expression`, `parse_add_sub`, `parse_mul_div`, `parse_primary` — 演算子優先度を考慮した式のパース

通常は `Redex::Parser.parse` を利用してください。内部メソッドはテストや拡張時に参照できます。

## AST ノード仕様

パーサが生成する主要なノード（Ruby ハッシュ）:

- 数値ノード

  { type: :number, value: <Integer | String> }

- 識別子ノード

  { type: :ident, name: :symbol_name }

- 二項演算ノード

  { type: :binary, op: "+"|"-"|"*"|"/", left: <node>, right: <node> }

- let/const 宣言ノード

  { type: :let, kind: :let|:const, name: :symbol_name, value: <node> }

注: `value` の数値は `Tokenizer` の実装により `Integer` になる場合があります。`name` はシンボル（`to_sym`）で格納されます。

## トークンとの関係

パーサは `Redex::Tokenizer` が生成するトークンの種別に依存します。主に利用するトークン種別は次の通りです（詳細は `docs/tokenizer.md` を参照）:

- `:number`, `:ident`, `:keyword`, `:op`, `:lparen`, `:rparen`

`let` / `const` は `:keyword`（`value` が文字列）として扱われます。演算子は `:op`（`value` が演算子文字）です。

## エラーと例外メッセージ

発生する主な `ParseError` メッセージ:

- `unexpected end` — 入力が途中で終わった場合
- `expected <type>, got <type>` — 期待するトークンが無い／不一致の場合
- `unexpected token <type>` — 想定していないトークンが来た場合

呼び出し側はこれらを rescue してユーザー向けのメッセージに変換するなどの処理を行ってください。

## 制限事項

- トップレベルは単一文/式のみ（複数文のシーケンスは未対応）
- AST に位置情報（行・列）は含まれない
- リテラルは数値のみ対応（文字列リテラル等は未実装）

## 将来の拡張案

- ステートメント配列（複数文）のサポート
- AST に位置情報を付与して詳細なエラー報告を可能にする
- 文字列リテラルや複合演算子の追加
- `parse` のオプションでトークンや位置情報を返す API 拡張

## テスト

`spec/parser_spec.rb` に次のようなケースを用意してください:

- 正常系: 単純な演算、優先度（`*`/`/` vs `+`/`-`）、括弧、`let` 宣言
- 異常系: 不完全な入力（`unexpected end`）、期待トークン不一致、未知トークン

既存の `spec/parser_spec.rb` を確認し、ドキュメントの例と整合する期待値を追加してください。

## 関連ファイル

- 実装: lib/redex/parser.rb
- トークナイザ: lib/redex/tokenizer.rb
- テスト: spec/parser_spec.rb

---
作成日: 2025-12-26
- `parse` のオプションでトークン/位置情報を返せるようにする

## 参照ファイル
- 実装: lib/redex/parser.rb
- トークナイザ: lib/redex/tokenizer.rb

---
作成日: 2025-12-26
