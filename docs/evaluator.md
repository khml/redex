# Redex 評価器（Evaluator）設計・仕様書

この文書は `lib/redex/evaluator.rb` に実装された評価器（Evaluator）の設計仕様、API、振る舞い、例外、制限事項、およびテスト方針をまとめます。

## 概要
- 目的: Parser が生成する AST（Ruby ハッシュ形式）を評価して値を返し、簡易な環境（変数マップ）を管理する
- 入力: Parser の返す AST（Hash）、オプションで `context`（初期値）と `ruby_resolver`（動的解決コールバック）
- 出力: 詳細な評価結果（`result`, `env`, `provenance`, `errors`, `diagnostics`, `meta`）
- 例外: 評価時のエラーは `Redex::EvaluationError`, `Redex::NameError`, `Redex::SyntaxError` を raise

## サポートする機能
- リテラル評価: `:number` ノード
- 識別子参照: `:ident` ノード（環境、context、ruby_resolver から値を取得）
- 二項演算: `:binary` ノードで `+ - * /` をサポート（左辺・右辺は再帰評価）
- 宣言/代入: `:let` および `:const` ノード（ノードの `:value` を評価して環境に格納）
- const 不変性: `const` で定義された名前への再代入を検出してエラーを発生
- context 検証: 初期化時に `context` の全値が数値であることを検証
- ruby_resolver 統合: 未解決の識別子を動的に解決するコールバック機構
- provenance 追跡: 各識別子がどこから来たか（script/context/ruby_resolver）を記録

## AST ノードと評価結果
以下は Parser が生成するノード種別と Evaluator の振る舞いの対応表です。

- 数値ノード

  - 入力ノード: `{ type: :number, value: <Integer> }`
  - 評価結果: `value` の数値をそのまま返す

- 識別子ノード

  - 入力ノード: `{ type: :ident, name: :symbol_name }`
  - 評価: 以下の優先順位で解決を試みる
    1. スクリプト内で定義された名前（`env`）
    2. `context` で提供された値
    3. `ruby_resolver` コールバックによる動的解決
  - 存在しない場合: `Redex::NameError` を発生させる（メッセージ: `undefined variable <name>`）

- 二項演算ノード

  - 入力ノード: `{ type: :binary, op: '+'|'-'|'*'|'/', left: <node>, right: <node> }`
  - 評価手順: 左右の子ノードを再帰的に `eval` して数値を得る、その後 `op` に応じた算術を実行
  - 例外: 未知の `op` の場合は `Redex::EvaluationError` を発生（`unknown op <op>`）
  - `/` は整数除算を想定し、右辺が `0` の場合は `Redex::EvaluationError` を発生（`division by zero`）

- let/const ノード

  - 入力ノード: `{ type: :let, kind: :let|:const, name: :symbol_name, value: <node> }`
  - 評価手順: `value` を評価して結果を環境に `env[name] = value` として格納、格納した値を返す
  - const 不変性: `const` で定義された名前への再代入を試みると `Redex::EvaluationError` を発生
  - 数値検証: 代入される値が数値でない場合は `Redex::EvaluationError` を発生

### AST / 評価入力（期待されるハッシュ構造）

Evaluator が受け取る `node` はパーサが生成する上記の AST ハッシュです。代表的な構造は `docs/parser.md` の "AST ハッシュ構造（詳細）" を参照してください。例を繰り返すと:

- 数値ノード: `{ type: :number, value: 3 }`
- 識別子ノード: `{ type: :ident, name: :x }`
- 二項ノード: `{ type: :binary, op: "+", left: <node>, right: <node> }`

### `Evaluator.evaluate` の戻り値ハッシュ（構造例）

`Evaluator.evaluate` は詳細な情報を含むハッシュを返します。各キーの期待型と例を示します。

- `:result` => `Numeric` - 評価結果の数値
  - 例: `7`
- `:env` => `Hash<Symbol, Numeric>` - 評価後の環境（変数/定数マップ）
  - 例: `{ x: 10 }`
- `:provenance` => `Hash<Symbol, String>` - 各識別子の出所
  - 例: `{ x: "script", y: "context" }`
- `:errors` => `Array<Hash>` - エラー情報オブジェクトの配列（将来的に詳細化）
  - 例: `[]` または `[ { type: "EvaluationError", message: "division by zero" } ]`
- `:diagnostics` => `Array<Hash>` - 診断情報の配列
  - 例: `[]`
- `:meta` => `Hash` - メタ情報（例: `:version` => `String`）
  - 例: `{ version: "0.1.0" }`

上記は現在の実装で返されるハッシュの形のおおよその仕様です。将来的に `:errors` / `:diagnostics` のオブジェクト仕様をより厳密に定義する予定です。

## 環境（env）と context の仕様
- Evaluator は初期環境として普通の Ruby ハッシュを受け取る（例: `{ x: 1 }`）。
- 環境のキーはシンボルを期待する（Parser は `name` を `to_sym` で格納する）。
- `context` は外部から提供される初期値のハッシュで、文字列キーまたはシンボルキーを使用できる。
- `context` の全値は数値（Integer または Float）である必要があり、非数値が含まれている場合は初期化時に `Redex::EvaluationError` を発生。
- スクリプト内で定義された名前は `context` の同名値をシャドウ（上書き）する。

## API

- クラス: `Redex::Evaluator`

 - コンストラクタ

  - `Evaluator.new(env = {}, context: {}, ruby_resolver: nil)` — 評価器インスタンスを生成
    - `env`: `Hash<Symbol, Numeric>` - 初期環境（キーは `Symbol`、値は `Integer` または `Float`）
    - `context`: `Hash<String|Symbol, Numeric>` - 外部から提供される初期値（キーは `String` または `Symbol`、値は数値）
    - `ruby_resolver`: `Proc` (シグネチャ: `(name: String, context: Hash) -> Numeric | nil`) - 未解決識別子を動的に解決するコールバック

- インスタンスメソッド

  - `#eval(node)` — 指定した AST ノードを評価して結果（数値）を返す。例外は各種エラークラスを発生させる。
    - 引数: `node`: `Hash`（AST ノード） - パーサが生成するノード（例: `{ type: :number, value: 1 }` 等）
    - 戻り値: `Numeric` (`Integer` | `Float`) - 評価結果の数値
  - `#env` — 現在の評価環境のコピーを返す（読み取り専用）
    - 戻り値: `Hash<Symbol, Numeric>` - 現在の環境の浅いコピー（キーは `Symbol`）
  - `#provenance` — 各識別子の出所情報のコピーを返す（読み取り専用）
    - 戻り値: `Hash<Symbol, String>` - 各識別子名 => 出所文字列(`"script"`, `"context"`, `"ruby_resolver"`)

- クラスメソッド

  - `Evaluator.evaluate(node, env = {}, context: {}, ruby_resolver: nil)` — 便宜的ラッパー。
    - 内部で `new(env, context: context, ruby_resolver: ruby_resolver).eval(node)` を実行
    - 詳細な評価結果をハッシュで返す（`:result`, `:env`, `:provenance`, `:errors`, `:diagnostics`, `:meta`）
    - 引数: `node`: `Hash`（AST ノード）
    - 引数: `env`: `Hash<Symbol, Numeric>` - 初期環境
    - 引数: `context`: `Hash<String|Symbol, Numeric>` - 外部コンテキスト
    - 引数: `ruby_resolver`: `Proc` - 未解決識別子解決用コールバック
    - 戻り値: `Hash` - 詳細な評価結果のハッシュ（型詳細は下記）

  戻り値の構造 (型):

  - `:result` => `Numeric` - 評価結果の数値
  - `:env` => `Hash<Symbol, Numeric>` - 評価後の環境
  - `:provenance` => `Hash<Symbol, String>` - 各識別子の出所
  - `:errors` => `Array<Hash>` - エラー情報オブジェクトの配列（将来仕様拡張）
  - `:diagnostics` => `Array<Hash>` - 診断情報の配列
  - `:meta` => `Hash` - メタ情報（例: `:version` => `String`）

## 戻り値の構造

`Evaluator.evaluate` は以下のキーを持つハッシュを返します:

- `:result` — 評価結果の数値
- `:env` — 評価後の環境（変数/定数のハッシュ）
- `:provenance` — 各識別子の出所（`"script"`, `"context"`, `"ruby_resolver"`）
- `:errors` — エラー配列（現在は常に空配列、将来的にエラー情報を格納する可能性あり）
- `:diagnostics` — 診断情報配列（現在は常に空配列）
- `:meta` — メタ情報（`:version` など）

## ruby_resolver の仕様

`ruby_resolver` は未解決の識別子を動的に解決するための Proc です。

- シグネチャ: `->(name, context) { numeric_value }`
  - `name`: 未解決の識別子名（文字列）
  - `context`: 現在の評価コンテキスト（`context` とスクリプト定義を合成したハッシュ）
  - 戻り値: 数値（Integer または Float）、または `nil`

- 動作:
  - 戻り値が数値の場合: その値を識別子の値として使用
  - 戻り値が `nil` の場合: `Redex::NameError` を発生
  - 戻り値が非数値の場合: `Redex::EvaluationError` を発生
  - 例外が発生した場合: その例外を伝播（Redex のエラー以外は `Redex::EvaluationError` でラップ）

## 例外とエラーメッセージ

評価時に発生する主要な例外:

- `Redex::NameError`: 識別子が未定義
  - メッセージ例: `undefined variable <name>`

- `Redex::EvaluationError`: 評価エラー
  - ゼロ除算: `division by zero`
  - 未知の演算子: `unknown op <op>`
  - 未知のノード種別: `unknown node type <type>`
  - const 再代入: `cannot reassign to const <name>`
  - 非数値の context: `context value for '<key>' must be numeric, got <class>`
  - 非数値の代入: `assigned value must be numeric, got <class>`
  - ruby_resolver の非数値戻り値: `ruby_resolver must return numeric value, got <class>`

- `Redex::SyntaxError`: パース時の構文エラー（Parser から発生）

呼び出し側はこれらを rescue してユーザー向けのエラーメッセージや位置情報付与などを行ってください。

## 使用例

```ruby
# 基本的な算術式の評価
ast = Redex::Parser.parse('1 + 2 * 3')
result = Redex::Evaluator.evaluate(ast)
# result[:result] => 7
# result[:env] => {}

# let による環境更新
ast = Redex::Parser.parse('let x = 10')
result = Redex::Evaluator.evaluate(ast)
# result[:result] => 10
# result[:env] => { x: 10 }
# result[:provenance] => { x: "script" }

# context からの識別子解決
ast = Redex::Parser.parse('x')
result = Redex::Evaluator.evaluate(ast, {}, context: { 'x' => 5 })
# result[:result] => 5
# result[:provenance] => { x: "context" }

# ruby_resolver による動的解決
resolver = ->(name, ctx) do
  case name
  when 'current_time' then Time.now.to_i
  else nil
  end
end

ast = Redex::Parser.parse('current_time + 1')
result = Redex::Evaluator.evaluate(ast, {}, ruby_resolver: resolver)
# result[:result] => (現在時刻のUNIXタイムスタンプ + 1)
# result[:provenance] => { current_time: "ruby_resolver" }

# const 不変性のチェック
evaluator = Redex::Evaluator.new({})
ast1 = Redex::Parser.parse('const pi = 3')
evaluator.eval(ast1)  # => 3

ast2 = Redex::Parser.parse('let pi = 4')
# evaluator.eval(ast2)  # => Redex::EvaluationError: cannot reassign to const pi
```

（注）このプロジェクトのドキュメント方針に合わせ、コードブロックは短い例に留めています。

## テスト
- 実装に対する基本的なテストは `spec/ast_eval_spec.rb` と `spec/interpreter_spec.rb` にあり、次の観点を検証する:
  - 演算子優先度に基づく算術評価
  - `let` と `const` による環境更新
  - 識別子の環境、context、ruby_resolver からの解決
  - const 不変性（再代入エラー）
  - context の数値検証
  - ruby_resolver の動作（正常系、nil 返却、非数値返却）
  - 異常系テスト: 未定義識別子、ゼロ除算、未知演算子、未知ノード

## 制限事項と今後の拡張案
- 現状の制限
  - 型は数値のみを想定（文字列、ブール等は未対応）
  - AST に位置情報がないためエラー時にソース位置を示せない
  - 単一グローバルスコープのみ（ブロックスコープや関数スコープは未対応）

- 拡張案
  - 環境にスコープ（ネスト）を導入し、ブロックスコープや関数スコープをサポートする
  - AST をクラスベースのノードに置き換え、型安全かつメソッド中心の評価を行う
  - 位置情報（行・列）を AST に付与してエラー報告を改善する
  - 文字列リテラルやブール値などの追加型をサポートする

## 関連ファイル
- 実装: lib/redex/evaluator.rb
- AST 定義（将来）: lib/redex/ast.rb
- パーサ（AST 生成）: lib/redex/parser.rb
- テスト: spec/ast_eval_spec.rb

---
作成日: 2025-12-26
