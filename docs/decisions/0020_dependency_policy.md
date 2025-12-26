# 依存管理方針

作成日: 2025-12-26

## 概要

プロジェクトの依存関係管理方針と vendor ディレクトリの扱いについて決定する。

## 現状

- 依存: RSpec のみ（開発用テストフレームワーク）
- バージョン: rspec 3.13.x（最新）
- vendor/ ディレクトリ: リポジトリに含まれているが、.gitignore で除外する設定になっている（不整合）

## 依存監査結果（2025-12-26）

```
$ bundle list
Gems included by the bundle:
  * diff-lcs (1.6.2)
  * rspec (3.13.2)
  * rspec-core (3.13.6)
  * rspec-expectations (3.13.5)
  * rspec-mocks (3.13.7)
  * rspec-support (3.13.6)

$ bundle outdated
Bundle up to date!
```

- 全依存関係が最新
- 脆弱性なし（既知の問題なし）

## 決定事項

### vendor ディレクトリの扱い

**決定**: vendor/ ディレクトリをリポジトリから削除し、.gitignore に従って無視する

**理由**:
1. vendor/ をリポジトリに含めるメリットが少ない（依存が RSpec のみで、広く利用可能）
2. リポジトリサイズの削減
3. .gitignore の設定と実態の整合性を保つ
4. 開発者は `bundle install` で簡単に依存をインストールできる

### 依存更新方針

- 定期的に `bundle update` と `bundle outdated` を実行して依存を最新に保つ
- セマンティックバージョニングに従い、マイナーアップデートは積極的に適用
- メジャーアップデート時はテストを実行して互換性を確認

### 新しい依存の追加基準

- 開発用（test, development グループ）の依存は必要に応じて追加可能
- 実行時依存（runtime）は極力避け、標準ライブラリで実装できる場合はそちらを優先
- 追加する場合は理由と用途をドキュメント化する

## 影響

- vendor/ ディレクトリを削除することで、リポジトリサイズが削減される
- 開発者は初回セットアップ時に `bundle install` を実行する必要がある（README に記載済み）
- CI/CD 環境では `bundle install` が必要（将来的に CI を導入する場合）

## 実施内容

1. vendor/ ディレクトリの削除
2. この決定ログの作成
3. README の確認（bundle install の手順が記載されていることを確認）

## 参考

- Gemfile: プロジェクトルートの Gemfile
- .gitignore: vendor/ を無視する設定
- README.md: セットアップ手順
