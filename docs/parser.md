# Redex パーサ設計・使用ドキュメント

この文書は `lib/redex/parser.rb` に実装されたパーサの設計仕様、使用例、AST 形式、および制限事項をまとめます。

## 概要
- 入力: 文字列（ソース）またはトークン配列
- 出力: Ruby ハッシュで表現された AST ノード（トップレベルは単一の文/式、または複数文を含む配列）
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
    - 返値: AST を表す `Hash`（単一文）または `Array<Hash>`（複数文のシーケンス）
    - 例外: 構文エラー時は `Redex::Parser::ParseError` を raise
    - パラメータ: `source`: `String | Array<Redex::Tokenizer::Token>` - 解析対象の入力
    - 戻り値: `Hash` - トップレベルの AST ノード（例: `{ type: :number, value: 1 }`）
    - 例外: `Redex::Parser::ParseError`


# パーサ（Parser）

## 概要

`Redex::Parser` は `lib/redex/parser.rb` に実装された再帰下降パーサです。入力は文字列（ソース）または `Tokenizer` の返すトークン配列で、出力は Ruby のハッシュで表現された AST（トップレベルは単一の文/式）です。構文エラーは `Redex::Parser::ParseError` を発生させます。

## API

- `Redex::Parser.parse(source)`
  - 引数: `source` — `String` または `Array<Token>`（`Token` は `Tokenizer` の `Struct`）
  - 戻り値: `Hash`（単一の文/式）または `Array<Hash>`（複数行の文を含むシーケンス）
  - 例外: 構文エラー時に `Redex::Parser::ParseError` を raise
  - 動作: `String` の場合は内部で `Redex::Tokenizer.tokenize` を呼んでトークナイズ後パースします。

  型注釈（主なメソッド）:

  - `initialize(tokens)`
    - 引数: `tokens`: `Array<Redex::Tokenizer::Token>` - トークン列
    - 戻り値: `Redex::Parser` インスタンス（コンストラクタのため暗黙的）

  - `current`
    - 戻り値: `Redex::Tokenizer::Token | nil` - 現在のトークン

  - `eat(expected_type = nil)`
    - 引数: `expected_type`: `Symbol | nil` - 期待するトークン種別
    - 戻り値: `Redex::Tokenizer::Token` - 消費したトークン、期待値不一致時は `ParseError` を raise

  - `parse_program`
    - 戻り値: `Hash | Array<Hash>` - トップレベルの文/式、または複数文の配列

  - `parse_statement`, `parse_let`
    - 引数/戻り値: 内部の AST ハッシュを受け渡し・生成する（`Hash`）

  - `parse_expression`, `parse_add_sub`, `parse_mul_div`, `parse_primary`
    - 引数: なし（内部状態のトークン列を利用）
    - 戻り値: `Hash` - 部分木の AST ノード

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

## AST ハッシュ構造（詳細）

パーサが返す AST は Ruby の `Hash` で表現され、各ノードは共通して `:type` キーを持ちます。以下は各ノードの期待されるハッシュ構造と具体例です。

- 数値ノード

  - 形: `{ type: :number, value: Integer }`
  - 例: `{ type: :number, value: 42 }`

- 識別子ノード

  - 形: `{ type: :ident, name: Symbol }`
  - 例: `{ type: :ident, name: :x }`

- 二項演算ノード

  - 形: `{ type: :binary, op: String, left: Hash, right: Hash }`
    - `op` は `"+"`, `"-"`, `"*"`, `"/"` のいずれか
    - `left` / `right` は再帰的に同様のノードハッシュを持つ
  - 例: `{ type: :binary, op: "+", left: { type: :number, value: 1 }, right: { type: :number, value: 2 } }`

- let/const 宣言ノード

  - 形: `{ type: :let, kind: :let | :const, name: Symbol, value: Hash }`
  - 例: `{ type: :let, kind: :let, name: :x, value: { type: :number, value: 10 } }`

トップレベルの AST は上記ノードのいずれかのハッシュ、もしくは複数文を評価する場合は `Array<Hash>` を返します。パーサは改行（`:newline` トークン）を文の区切りとして扱い、空行は無視されます。最終行の末尾改行は必須ではありません。

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
