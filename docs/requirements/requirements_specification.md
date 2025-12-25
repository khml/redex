# 要件定義書 — シンプル言語処理系（Ruby向け）

## プロジェクト概要

小規模な組込み用言語処理系をRubyで実装する。Rubyアプリケーションの内部で簡単に組み込み・評価可能で、以下の特徴を持つ：

- 入力は空白で区切られたトークン列のみを扱う（トークン間に必ず空白が入る）
- 演算子は四則演算（`+`, `-`, `*`, `/`）のみ
- 定数（const）と変数（let）の定義、式の評価を行う
- 変数/定数の評価時に、ホスト側（ユーザ）のRubyコード／関数を呼び出せる仕組みを提供
- 設計は単純であることを最優先とし、拡張は後から可能とする

## 用語定義

- 式（expression）: 数値リテラル、変数参照、または算術式
- 文（statement）: 定義（`const`／`let`）または式
- トークン: 空白で区切られる最小単位

## 対象外

- 括弧や関数定義、制御構造、論理演算子は本バージョンで扱わない
- JavaScriptや外部プロセスへの評価は扱わない（Rubyホスト内での呼び出しのみ）

## 機能要件

1. パーサ/評価
   - 入力は1行（または複数行）のテキスト。各行は1つまたは複数の文を含められる。
   - トークンは常に空白（スペース）で区切られる。
   - 文の文法（例）:
     - 定数定義: `const <IDENT> = <EXPR>`
     - 変数定義: `let <IDENT> = <EXPR>`
     - 式: `<TERM> ( ("+"|"-"|"*"|"/") <TERM> )*`
     - TERM: 数値リテラル（整数/浮動小数点）または識別子
   - 演算子の優先度は標準の算術優先度（`*`/`/` > `+`/`-`）。左結合。
   - 括弧はサポートしない（優先度は変数と演算子の標準規則で解決）。

2. 変数/定数のスコープ
   - 単一グローバルスコープを採用。
   - `const`で定義された名前は再代入不可。`let`は再代入可能。

3. 外部Ruby呼び出し（ユーザフック）と `context` の扱い
    - 全体の識別子解決順（優先度高 → 低）:
       1. スクリプト内で定義された名前（既に `let` / `const` で定義されているもの）
       2. `context` 引数で渡された事前定義の名前（ハッシュのキー）
       3. 解決されない識別子や `ruby:` プレフィックスを持つ式に対して呼び出される `ruby_resolver`
    - `context`:
       - 呼び出し側が初期の環境値（変数・定数）を提供するためのハッシュ。例: `{ 'x' => 2, 'env_val' => 10 }`。
       - スクリプト内で同名の名前が定義された場合、スクリプト側の定義が `context` をシャドウ（上書き）する。
      - `context` の値は数値（Integer/Float）であることを推奨。非数値が渡された場合は評価時に `Redex::EvaluationError` を投げる。
    - `ruby_resolver` (ユーザフック):
       - 未解決の識別子、または `ruby:` プレフィックスを持つ式を解決するために呼び出される `Proc` または `callable` を受け取れる。
       - シグネチャ: `->(code_or_ident, context_hash) { numeric_value_or_raise }`。
          - `code_or_ident`: 未解決識別子の名前、または `ruby:` に続くコード文字列。
          - `context_hash`: 現在の評価コンテキスト（`context` とスクリプト定義を合成したもののビュー）。
      - 返却値は数値であることが期待される。`nil` や数値以外を返した場合は `Redex::EvaluationError` を投げる。
       - 例外が発生した場合、評価は中断され呼び出し元に例外が伝播する。
    - セキュリティ注意: `ruby_resolver` が任意のRubyコードを実行できるため、呼び出しは信頼された環境で行い、必要に応じてサンドボックス化を検討する。
    - 例（Ruby）:

```ruby
source = "x + 1"
result = Redex::Interpreter.evaluate(
   source,
   context: { 'x' => 2 },
   ruby_resolver: ->(code_or_ident, ctx) { nil } # 未使用時は nil を返しても良い
)
# result => 3

source2 = "y + 1"
result2 = Redex::Interpreter.evaluate(
   source2,
   context: {},
   ruby_resolver: ->(code_or_ident, ctx) do
      case code_or_ident
      when 'y' then 10
      when /^ruby:/ then eval(code_or_ident.sub(/^ruby:/, ''))
      else raise Redex::NameError, "unresolved: #{code_or_ident}"
      end
   end
)
# result2 => 11
```

4. API（外部公開インターフェース）
   - 最小API例（Ruby）:

```ruby
result = Redex::Interpreter.evaluate(
   source_text,
   context: { 'x' => 1.5 },
   ruby_resolver: ->(code_or_ident, ctx) { /* return numeric value or raise */ }
)
```

   - `source_text`: 評価する文字列
   - `context`: 事前に定義する変数/定数のハッシュ
   - `ruby_resolver`: 未解決識別子または`ruby:`で始まる式を解決するためのProc。引数は `(code_or_ident, context)` で数値を返す。

5. エラーハンドリング
   - 構文エラー、未定義識別子（resolverが値を返さない場合）、ゼロ除算は明確な例外クラス（例: `Redex::SyntaxError`, `Redex::NameError`, `Redex::EvaluationError`）を返す。

6. 入出力
   - 入力: テキスト（UTF-8）
   - 出力: 評価結果（数値）および定義の状態（内部環境ハッシュを取得可能）

   ## 戻り値（評価結果の構造）

   評価呼び出しが返すデータ構造は、ホスト側での使いやすさとデバッグ性を考慮して以下を含むことを推奨する。

   - `result`: 最後に評価された式の評価値（数値）。
   - `env`: 評価後の変数/定数テーブル（ハッシュ）。スクリプト内定義と `context` の合成結果を返す。
   - `errors`: 実行中に発生したエラーの配列（発生しなければ空配列）。各エントリは `{ type:, message:, location: }` の形を推奨。
   - `diagnostics`: 構文警告や非致命的な注意の配列（任意）。
   - `provenance`: 各識別子の出所を示すハッシュ。キーは識別子名、値は `script` / `context` / `ruby_resolver` などの文字列。
   - `trace`（任意）: 評価の簡易トレース（各代入や主要評価ステップのログ）。デバッグ時に有用。
   - `meta`: 実行に関するメタ情報（例: `time_ms`, `version`, `options` など）。
   - `side_effects`（任意）: `ruby_resolver` 等で発生した副作用の要約やログ（必要に応じて提供）。

   推奨される最小戻り値フォーマット（Rubyハッシュの例）:

   ```ruby
   {
      result: 42.0,
      env: { "a" => 10, "pi" => 3.14 },
      diagnostics: [],
      errors: [],
      provenance: { "a" => "script", "x" => "context", "now" => "ruby_resolver" },
      meta: { time_ms: 1.2, version: "0.1.0" }
   }
   ```

   運用上の注意:
   - 最低限 `result` と `env` を必ず返し、デバッグや問題解析のために `errors` と `provenance` を付けることを推奨する。
   - `ruby_resolver` を通じたコード実行に起因する副作用や例外については、`errors` と `side_effects` で明示的に通知するようにする。


## 非機能要件

- 設計/実装言語: Ruby（3.xを想定）
- パフォーマンス: 単一式の評価はミリ秒オーダーで完了すること。大量評価の際はAPIとしてバルク評価を提供する。
- セキュリティ: `ruby_resolver`による任意Ruby実行は危険を伴うため、API呼び出し側が責任を負う。将来的にサンドボックス化オプションを検討する。
- テスト: 単体テストを充実させる（構文、演算、優先度、エラーパス、ruby_resolverの動作）
- ドキュメント: `docs/` に使い方とAPI例を追加

## 受け入れ基準

- 基本評価:
  - `1 + 2 * 3` → `7`
  - `let a = 5` の後に `a * 2` → `10`
  - `const pi = 3.14` を再代入しようとすると例外を返す
- 未定義識別子の解決:
  - `x + 1` を評価するとき、`ruby_resolver`が `x` を `2` と返せば結果は `3` になる
  - `const now = ruby:Time.now.to_i` のような形で `ruby:` を使い、`ruby_resolver` が呼ばれ正しく数値を返すこと
- エラーパス:
   - `1 / 0` は `Redex::EvaluationError` を返す
   - 構文的に不正な入力は `Redex::SyntaxError` を返す

## 実装方針（短期）

1. パーサとAST: 単純なトークン分割（空白区切り）→ 再帰下降ではなく、演算子優先度に基づくシャントイングヤードは不要。手作業の優先度処理でOK。
2. 評価器: ASTノード毎に`eval(context, resolver)`メソッドを用意。
3. 外部フック: `ruby_resolver` を `Proc` として受け取り、未定義名前または `ruby:` プレフィックスを渡す。
4. テスト: RSpecまたはMinitestで十分な網羅（正常系・異常系）を実装。

## 拡張案（将来）

- 括弧対応
- 関数（ユーザ定義）追加
- 名前空間/スコープの導入
- サンドボックス評価（別プロセスや`$SAFE`的な隔離）

---

作成日: 2025-12-25
作成者: (未設定)
