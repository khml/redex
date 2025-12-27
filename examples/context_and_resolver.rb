#!/usr/bin/env ruby
# frozen_string_literal: true

# context と ruby_resolver の活用例
#
# Redex の context と ruby_resolver を使って、外部データや Ruby コードと
# 連携する方法を示すサンプルです。
#
# 使い方:
#   ruby examples/context_and_resolver.rb
#
# セキュリティ注意:
#   ruby_resolver は任意の Ruby コードを実行できます。
#   信頼できない入力には使用しないでください。

require_relative '../lib/redex'

puts "=" * 60
puts "Redex: context と ruby_resolver の活用例"
puts "=" * 60
puts ""

# ========================================
# 例1: context を使った外部データの注入
# ========================================
puts "【例1】 context を使った外部データの注入"
puts ""

# アプリケーション設定を context として渡す
app_config = {
  'max_users' => 100,
  'timeout' => 30,
  'retry_count' => 3
}

expression = 'max_users * retry_count'
puts "式: #{expression}"
puts "context: #{app_config.inspect}"

result = Redex::Interpreter.evaluate(expression, context: app_config)
puts "結果: #{result[:result]}"
puts "出所: #{result[:provenance].inspect}"
puts ""

# ========================================
# 例2: ruby_resolver を使った動的値の解決
# ========================================
puts "【例2】 ruby_resolver を使った動的値の解決"
puts ""

# 動的な値を提供する resolver
dynamic_resolver = lambda do |name, _ctx|
  case name
  when 'current_hour'
    Time.now.hour
  when 'random_value'
    rand(1..100)
  when 'pi'
    3.14159
  else
    nil # 解決できない場合は nil を返す
  end
end

expression = 'current_hour + 10'
puts "式: #{expression}"
puts "ruby_resolver: 時刻やランダム値を提供"

result = Redex::Interpreter.evaluate(expression, ruby_resolver: dynamic_resolver)
puts "結果: #{result[:result]}"
puts "出所: #{result[:provenance].inspect}"
puts ""

# ========================================
# 例3: context と ruby_resolver の併用
# ========================================
puts "【例3】 context と ruby_resolver の併用"
puts ""

# context: 静的な設定値
static_config = {
  'base_price' => 1000,
  'tax_rate' => 10
}

# ruby_resolver: 動的な値（例: ユーザー固有の割引率）
user_resolver = lambda do |name, _ctx|
  case name
  when 'user_discount'
    # 実際のアプリでは DB や外部 API から取得することを想定
    15 # 15% 割引
  when 'is_premium'
    1 # プレミアム会員フラグ (1 = true, 0 = false)
  else
    nil
  end
end

# 価格計算の例
# (base_price - user_discount) * (100 + tax_rate) / 100
expression = '(base_price - user_discount) * (100 + tax_rate) / 100'
puts "式: #{expression}"
puts "context: #{static_config.inspect}"
puts "ruby_resolver: ユーザー固有データを提供"

result = Redex::Interpreter.evaluate(
  expression,
  context: static_config,
  ruby_resolver: user_resolver
)
puts "結果: #{result[:result]}"
puts "出所: #{result[:provenance].inspect}"
puts ""

# ========================================
# 例4: 解決の優先順位を確認
# ========================================
puts "【例4】 解決の優先順位（スクリプト内定義 > context > ruby_resolver）"
puts ""

# context に x を定義
context_with_x = { 'x' => 100 }

# ruby_resolver にも x を定義（こちらは使われない）
resolver_with_x = lambda do |name, _ctx|
  name == 'x' ? 999 : nil
end

# スクリプト内で x を let で定義
expression = "let x = 10\nx * 2"
puts "式: #{expression}"
puts "context['x']: 100"
puts "ruby_resolver['x']: 999"
puts ""

result = Redex::Interpreter.evaluate(
  expression,
  context: context_with_x,
  ruby_resolver: resolver_with_x
)
puts "結果: #{result[:result]}"
puts "使用された x の値: #{result[:result] / 2}"
puts "=> スクリプト内の let が最優先されます"
puts ""

# ========================================
# 例5: ruby_resolver でエラーハンドリング
# ========================================
puts "【例5】 ruby_resolver でのエラーハンドリング"
puts ""

# 外部 API 呼び出しを模擬する resolver
api_resolver = lambda do |name, _ctx|
  case name
  when 'api_value'
    begin
      # 実際のアプリでは HTTP リクエストなどを想定
      # ここでは成功ケースを返す
      42
    rescue StandardError => e
      # エラー時はログを出して nil を返す
      warn "API 呼び出し失敗: #{e.message}"
      nil
    end
  else
    nil
  end
end

expression = 'api_value + 8'
puts "式: #{expression}"
puts "ruby_resolver: 外部 API を模擬"

result = Redex::Interpreter.evaluate(expression, ruby_resolver: api_resolver)
puts "結果: #{result[:result]}"
puts ""

# ========================================
# 例6: 実用的なユースケース - 設定ファイルの式評価
# ========================================
puts "【例6】 実用的なユースケース - 設定ファイルの式評価"
puts ""

# 設定ファイルで定義された式を評価するシナリオ
config_expressions = {
  max_connections: 'cpu_cores * 10',
  cache_size: 'available_memory / 4',
  timeout: 'base_timeout + latency'
}

# システム情報を提供する resolver
system_resolver = lambda do |name, _ctx|
  case name
  when 'cpu_cores'
    # 実際には Etc.nprocessors などを使用
    4
  when 'available_memory'
    # 実際には /proc/meminfo などから取得
    8192 # MB
  when 'base_timeout'
    30
  when 'latency'
    5
  else
    nil
  end
end

puts "設定式の評価結果:"
config_expressions.each do |key, expr|
  result = Redex::Interpreter.evaluate(expr, ruby_resolver: system_resolver)
  puts "  #{key}: #{expr} => #{result[:result]}"
end
puts ""

# ========================================
# 例7: context の出所追跡
# ========================================
puts "【例7】 context の出所追跡（provenance）"
puts ""

# 複数の変数を使う式
multi_var_context = {
  'a' => 10,
  'b' => 20,
  'c' => 30
}

expression = 'a + b * c'
puts "式: #{expression}"
puts "context: #{multi_var_context.inspect}"

result = Redex::Interpreter.evaluate(expression, context: multi_var_context)
puts "結果: #{result[:result]}"
puts "各変数の出所:"
result[:provenance].each do |var, source|
  puts "  #{var} => #{source}"
end
puts ""

puts "=" * 60
puts "サンプル終了"
puts "=" * 60
