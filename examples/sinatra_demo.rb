#!/usr/bin/env ruby
# frozen_string_literal: true

# Sinatra を使った Web API の例
#
# Redex ライブラリを HTTP API として公開するサンプルです。
# JSON で式を受け取り、評価結果を JSON で返します。
#
# セットアップ:
#   gem install sinatra
#   または Gemfile に追加して bundle install
#
# 起動方法:
#   ruby examples/sinatra_demo.rb
#
# 使用例:
#   curl -X POST http://localhost:4567/evaluate \
#     -H "Content-Type: application/json" \
#     -d '{"expression": "1 + 2 * 3"}'
#
#   curl -X POST http://localhost:4567/evaluate \
#     -H "Content-Type: application/json" \
#     -d '{"expression": "x + y", "context": {"x": 10, "y": 5}}'
#
# セキュリティ警告:
#   - このサンプルは教育目的です
#   - 本番環境では以下の対策が必要です:
#     * 入力サイズの制限
#     * レート制限
#     * タイムアウト設定
#     * ruby_resolver の無効化または厳重な制限
#     * HTTPS の使用
#     * 認証・認可の実装

begin
  require 'sinatra'
rescue LoadError
  puts "エラー: Sinatra がインストールされていません"
  puts "以下のコマンドでインストールしてください:"
  puts "  gem install sinatra"
  exit 1
end

require 'json'
require_relative '../lib/redex'

# Sinatra の設定
set :port, 4567
set :bind, '0.0.0.0'

# JSON パースエラーのハンドリング
before do
  if request.content_type&.include?('application/json') && !request.body.read.empty?
    request.body.rewind
    begin
      @json_body = JSON.parse(request.body.read)
    rescue JSON::ParserError => e
      halt 400, { error: 'Invalid JSON', message: e.message }.to_json
    end
  end
end

# ヘルスチェック
get '/health' do
  content_type :json
  { status: 'ok', service: 'Redex Evaluator API' }.to_json
end

# ルートパス - API 情報
get '/' do
  content_type :json
  {
    service: 'Redex Evaluator API',
    version: Redex::VERSION,
    endpoints: {
      health: 'GET /health',
      evaluate: 'POST /evaluate'
    },
    usage: {
      evaluate: {
        method: 'POST',
        content_type: 'application/json',
        body: {
          expression: '(required) 評価する式',
          context: '(optional) 初期変数のハッシュ'
        },
        example: {
          expression: '1 + 2 * 3',
          context: { x: 10, y: 5 }
        }
      }
    }
  }.to_json
end

# 式の評価エンドポイント
post '/evaluate' do
  content_type :json

  # リクエストボディの検証
  unless @json_body
    halt 400, { error: 'Missing request body' }.to_json
  end

  expression = @json_body['expression']
  unless expression
    halt 400, { error: 'Missing required field: expression' }.to_json
  end

  # 入力サイズの制限（セキュリティ対策）
  if expression.length > 10_000
    halt 400, { error: 'Expression too long', max_length: 10_000 }.to_json
  end

  # context の取得（オプション）
  context = @json_body['context'] || {}

  # context の検証
  unless context.is_a?(Hash)
    halt 400, { error: 'Invalid context: must be a hash/object' }.to_json
  end

  # context のキーを文字列に変換
  context = context.transform_keys(&:to_s)

  # 評価の実行
  begin
    result = Redex::Interpreter.evaluate(expression, context: context)

    # 成功レスポンス
    {
      success: true,
      result: result[:result],
      environment: result[:env],
      provenance: result[:provenance],
      expression: expression
    }.to_json

  rescue Redex::SyntaxError => e
    # 構文エラー
    halt 400, {
      success: false,
      error: 'SyntaxError',
      message: e.message,
      expression: expression
    }.to_json

  rescue Redex::NameError => e
    # 名前解決エラー
    halt 400, {
      success: false,
      error: 'NameError',
      message: e.message,
      expression: expression
    }.to_json

  rescue Redex::EvaluationError => e
    # 評価エラー（ゼロ除算など）
    halt 400, {
      success: false,
      error: 'EvaluationError',
      message: e.message,
      expression: expression
    }.to_json

  rescue StandardError => e
    # その他の予期しないエラー
    warn "Unexpected error: #{e.class} - #{e.message}"
    warn e.backtrace.join("\n")

    halt 500, {
      success: false,
      error: 'InternalServerError',
      message: 'An unexpected error occurred'
    }.to_json
  end
end

# バッチ評価エンドポイント（複数の式を一度に評価）
post '/evaluate/batch' do
  content_type :json

  unless @json_body
    halt 400, { error: 'Missing request body' }.to_json
  end

  expressions = @json_body['expressions']
  unless expressions && expressions.is_a?(Array)
    halt 400, { error: 'Missing or invalid field: expressions (must be an array)' }.to_json
  end

  # バッチサイズの制限
  if expressions.length > 100
    halt 400, { error: 'Too many expressions', max_count: 100 }.to_json
  end

  # 共通 context の取得
  context = @json_body['context'] || {}
  context = context.transform_keys(&:to_s)

  # 各式を評価
  results = expressions.map.with_index do |expr, idx|
    begin
      # 式のサイズチェック
      if expr.length > 10_000
        {
          index: idx,
          success: false,
          error: 'ExpressionTooLong',
          expression: expr[0...50] + '...'
        }
        next
      end

      result = Redex::Interpreter.evaluate(expr, context: context)
      {
        index: idx,
        success: true,
        result: result[:result],
        environment: result[:env],
        expression: expr
      }

    rescue Redex::SyntaxError, Redex::NameError, Redex::EvaluationError => e
      {
        index: idx,
        success: false,
        error: e.class.name.split('::').last,
        message: e.message,
        expression: expr
      }
    end
  end

  {
    success: true,
    count: expressions.length,
    results: results
  }.to_json
end

# エラーハンドラ
error 404 do
  content_type :json
  { error: 'Not Found', message: 'Endpoint not found' }.to_json
end

# サーバー起動時のメッセージ
if __FILE__ == $PROGRAM_NAME
  puts "=" * 60
  puts "Redex Evaluator API Server"
  puts "=" * 60
  puts "Server starting on http://localhost:4567"
  puts ""
  puts "利用可能なエンドポイント:"
  puts "  GET  /          - API 情報"
  puts "  GET  /health    - ヘルスチェック"
  puts "  POST /evaluate  - 式の評価"
  puts "  POST /evaluate/batch - バッチ評価"
  puts ""
  puts "使用例:"
  puts "  curl -X POST http://localhost:4567/evaluate \\"
  puts "    -H 'Content-Type: application/json' \\"
  puts "    -d '{\"expression\": \"1 + 2 * 3\"}'"
  puts ""
  puts "セキュリティ警告:"
  puts "  このサンプルは教育目的です。本番環境では適切な"
  puts "  セキュリティ対策を実装してください。"
  puts "=" * 60
  puts ""
end
