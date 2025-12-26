# Redex 評価器（Evaluator）設計・仕様書

この文書は `lib/redex/evaluator.rb` に実装された評価器（Evaluator）の設計仕様、API、振る舞い、例外、制限事項、およびテスト方針をまとめます。

## 概要
- 目的: Parser が生成する AST（Ruby ハッシュ形式）を評価して値を返し、簡易な環境（変数マップ）を管理する
- 入力: Parser の返す AST（Hash）
- 出力: 評価結果（数値など）および評価時に更新される環境ハッシュ
- 例外: 評価時のエラーは `Redex::Evaluator::EvalError` を raise

## サポートする機能（現状）
- リテラル評価: `:number` ノード
- 識別子参照: `:ident` ノード（環境から値を取得）
- 二項演算: `:binary` ノードで `+ - * /` をサポート（左辺・右辺は再帰評価）
- 宣言/代入: `:let` および `:const` ノード（ノードの `:value` を評価して環境に格納）

## AST ノードと評価結果
以下は Parser が生成するノード種別と Evaluator の振る舞いの対応表です。

- 数値ノード

  - 入力ノード: `{ type: :number, value: <Integer> }`
  - 評価結果: `value` の数値をそのまま返す

- 識別子ノード

  - 入力ノード: `{ type: :ident, name: :symbol_name }`
  - 評価: 環境ハッシュ（キーはシンボル）から `:symbol_name` を参照
  - 存在しない場合: `EvalError` を発生させる（メッセージ: `undefined variable <name>`）

- 二項演算ノード

  - 入力ノード: `{ type: :binary, op: '+'|'-'|'*'|'/', left: <node>, right: <node> }`
  - 評価手順: 左右の子ノードを再帰的に `eval` して数値を得る、その後 `op` に応じた算術を実行
  - 例外: 未知の `op` の場合は `EvalError` を発生（`unknown op <op>`）
  - `/` は整数除算を想定し、右辺が `0` の場合は `EvalError` を発生（`division by zero`）

- let/const ノード

  - 入力ノード: `{ type: :let, kind: :let|:const, name: :symbol_name, value: <node> }`
  - 評価手順: `value` を評価して結果を環境に `env[name] = value` として格納、格納した値を返す
  - 現状: `let` と `const` は同一の振る舞い（不変性チェックは未実装）

## 環境（env）仕様
- Evaluator は初期環境として普通の Ruby ハッシュを受け取る（例: `{ x: 1 }`）。
- 環境のキーはシンボルを期待する（Parser は `name` を `to_sym` で格納する）。
- `evaluate(node, env = {})` の呼び出しでは、渡した `env` オブジェクトが直接更新される（破壊的更新）。

## API

- クラス: `Redex::Evaluator`

- コンストラクタ

  - `Evaluator.new(env = {})` — 評価器インスタンスを生成（`env` は Hash）

- インスタンスメソッド

  - `#eval(node)` — 指定した AST ノードを評価して結果を返す。例外は `EvalError` を発生させる。

- クラスメソッド

  - `Evaluator.evaluate(node, env = {})` — 便宜的ラッパー。内部で `new(env).eval(node)` を実行する。

## 例外とエラーメッセージ
- `Redex::Evaluator::EvalError` が発生する主要ケース:
  - 識別子未定義: `undefined variable <name>`
  - ゼロ除算: `division by zero`
  - 未知の演算子: `unknown op <op>`
  - 未知のノード種別: `unknown node type <type>`

呼び出し側はこれらを rescue してユーザー向けのエラーメッセージや位置情報付与などを行ってください。

## 使用例

```
# AST を直接評価
ast = Redex::Parser.parse('1 + 2 * 3')
result = Redex::Evaluator.evaluate(ast)
# result => 7

# let による環境更新
ast = Redex::Parser.parse('let x = 10')
env = {}
Redex::Evaluator.evaluate(ast, env)
# env => { x: 10 }

# 識別子解決
ast = Redex::Parser.parse('x')
Redex::Evaluator.evaluate(ast, { x: 5 }) # => 5
```

（注）このプロジェクトのドキュメント方針に合わせ、コードブロックは短い例に留めています。

## テスト
- 実装に対する基本的なテストは `spec/ast_eval_spec.rb` にあり、次の観点を検証する:
  - 演算子優先度に基づく算術評価
  - `let` による環境更新
  - 識別子の環境からの解決

今後の追加テスト候補:
- `const` の不変性（再代入エラー）
- 異常系テスト: 未定義識別子、ゼロ除算、未知演算子、未知ノード

## 制限事項と今後の拡張案
- 現状の制限
  - `let` と `const` の区別は無く、どちらも単純に代入する
  - 型は数値のみを想定（文字列、ブール等は未対応）
  - AST に位置情報がないためエラー時にソース位置を示せない

- 拡張案
  - `const` の不変性チェックを実装して再代入を禁止する
  - 環境にスコープ（ネスト）を導入し、ブロックスコープや関数スコープをサポートする
  - AST をクラスベースのノードに置き換え、型安全かつメソッド中心の評価を行う
  - 位置情報（行・列）を AST に付与してエラー報告を改善する

## 関連ファイル
- 実装: lib/redex/evaluator.rb
- AST 定義（将来）: lib/redex/ast.rb
- パーサ（AST 生成）: lib/redex/parser.rb
- テスト: spec/ast_eval_spec.rb

---
作成日: 2025-12-26
