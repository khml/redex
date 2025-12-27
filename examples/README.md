# Redex サンプルアプリケーション

このディレクトリには、Redex ライブラリを実際のアプリケーションで活用するサンプルが含まれています。

## サンプル一覧

### 1. CLI 電卓アプリ (`cli_calculator.rb`)

対話型の計算機アプリケーション。REPL、コマンドライン引数、パイプ入力に対応。

**使い方:**

```bash
# 対話モード
./examples/cli_calculator.rb

# コマンドライン引数
./examples/cli_calculator.rb "1 + 2 * 3"

# パイプ入力
echo -e "let x = 10\nx * 2" | ./examples/cli_calculator.rb
```

**機能:**
- 履歴表示 (`history`)
- 環境リセット (`clear`)
- ヘルプ表示 (`help`)
- 変数・定数の永続化

---

### 2. context と ruby_resolver の活用例 (`context_and_resolver.rb`)

外部データや動的な値を Redex と連携する方法を示すサンプル集。

**使い方:**

```bash
./examples/context_and_resolver.rb
```

**含まれる例:**
- context を使った外部データの注入
- ruby_resolver による動的値の解決
- context と ruby_resolver の併用
- 解決の優先順位の確認
- 実用的なユースケース

---

### 3. Sinatra Web API (`sinatra_demo.rb`)

HTTP API として Redex を公開する例。

**セットアップ:**

```bash
# Sinatra のインストール（初回のみ）
gem install sinatra
```

**起動:**

```bash
./examples/sinatra_demo.rb
```

**API エンドポイント:**

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

**セキュリティ警告:**  
このサンプルは教育目的です。本番環境では適切なセキュリティ対策（レート制限、HTTPS、認証など）を実装してください。

---

### 4. Rake タスク統合 (`rake_task.rb`)

ビルドプロセスで設定値を式で計算する例。

**使い方:**

```bash
# Rakefile に require して使用
# require_relative 'examples/rake_task'

# または直接実行
bundle exec rake -f examples/rake_task.rb config:generate
bundle exec rake -f examples/rake_task.rb config:validate
bundle exec rake -f examples/rake_task.rb config:from_env
```

**タスク:**
- `config:generate` - システム情報から設定ファイルを生成
- `config:validate` - 設定式の妥当性を検証
- `config:show` - 現在の設定値を表示
- `config:from_env` - 環境変数から設定値を計算

**ユースケース:**
- ビルド時に設定ファイルを動的に生成
- 環境変数から設定値を計算
- デプロイ前の設定値の検証

---

## テスト

全サンプルの動作確認用テストが用意されています。

```bash
# サンプルのテストを実行
bundle exec rspec spec/examples_spec.rb

# 全テストを実行
bundle exec rspec
```

---

## セキュリティに関する注意

### ruby_resolver の使用について

`ruby_resolver` は任意の Ruby コードを実行できるため、信頼できない入力には使用しないでください。

**安全な使用例:**
- 環境変数からの値の取得
- システム情報（CPU コア数など）の取得
- アプリケーション内部の設定値の解決

**危険な使用例:**
- ユーザー入力をそのまま `eval` する
- 外部から受け取った文字列を解決に使用する

### Web API の公開について

`sinatra_demo.rb` は教育目的のサンプルです。本番環境で使用する場合は、以下の対策が必須です:

- **入力検証**: サイズ制限、形式チェック（実装済み）
- **レート制限**: DoS 攻撃の防止
- **タイムアウト**: 長時間実行の防止
- **HTTPS**: 通信の暗号化
- **認証・認可**: アクセス制御
- **監視・ログ**: 不正アクセスの検知

---

## ライセンス

これらのサンプルは Redex プロジェクトと同じライセンスで提供されます。
