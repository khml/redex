# Decision 0008 — アーキテクチャ基本方針

作成日: 2025-12-25

ステータス: 記録済み

決定事項:
- `context` は呼び出し側が渡す初期環境ハッシュとし、値は数値のみ許容する（数値以外で `Redex::EvaluationError` を投げる）。
- 識別子解決の順序は「スクリプト定義 → context → ruby_resolver」。これによりローカル定義が優先される。
- `ruby_resolver` はホスト呼び出しのフックとして `->(code_or_ident, context_hash)` シグネチャを採用する。
- 評価APIは最低限 `result` と `env` を返し、必要に応じて `errors`, `provenance`, `meta` を含める。

背景:
- 安全性と簡潔さのため、`context` の型制約を厳格にする。
- `ruby_resolver` をフック化することでホスト側の拡張やテストの容易化を狙う。

今後の検討事項:
- `ruby_resolver` の戻り値の仕様を厳密化（例: 未解決は `nil` または専用構造体で表す）
- サンドボックス化の詳細設計（別チケット）
