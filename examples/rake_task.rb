# frozen_string_literal: true

# Rake タスクでの Redex 利用例
#
# ビルドプロセスで設定値を式で計算する例を示します。
# このファイルを Rakefile に require することで使用できます。
#
# 使い方:
#   1. このファイルを Rakefile に require する
#      require_relative 'examples/rake_task'
#   
#   2. タスクを実行する
#      bundle exec rake config:generate
#      bundle exec rake config:validate
#      bundle exec rake config:show
#
# ユースケース:
#   - ビルド時に設定ファイルを動的に生成
#   - 環境変数から設定値を計算
#   - デプロイ前の設定値の検証

require_relative '../lib/redex'
require 'yaml'
require 'json'

namespace :config do
  desc 'Redex を使って設定ファイルを生成'
  task :generate do
    puts "設定ファイルを生成します..."
    puts ""

    # 設定テンプレート（式を含む）
    config_template = {
      'database' => {
        'pool_size' => 'cpu_cores * 5',
        'timeout' => 'base_timeout + 10',
        'max_connections' => 'pool_size * 2'
      },
      'cache' => {
        'size_mb' => 'available_memory / 8',
        'ttl_seconds' => '60 * 15' # 15分
      },
      'worker' => {
        'concurrency' => 'cpu_cores * 2',
        'queue_size' => 'concurrency * 100'
      }
    }

    # システム情報を提供する resolver
    system_resolver = lambda do |name, _ctx|
      case name
      when 'cpu_cores'
        # 実際のCPUコア数を取得（フォールバックあり）
        require 'etc'
        Etc.nprocessors
      when 'available_memory'
        # 簡易実装: 実際はシステムから取得
        8192 # MB
      when 'base_timeout'
        30 # 秒
      else
        nil
      end
    end

    # 設定値を評価
    resolved_config = {}
    context = {} # 前の値を後の式で参照できるように

    config_template.each do |section, values|
      resolved_config[section] = {}
      
      values.each do |key, expression|
        result = Redex::Interpreter.evaluate(
          expression.to_s,
          context: context,
          ruby_resolver: system_resolver
        )
        
        resolved_value = result[:result]
        resolved_config[section][key] = resolved_value
        
        # 後の式で参照できるように context に追加
        context[key] = resolved_value
        
        puts "  #{section}.#{key}: #{expression} => #{resolved_value}"
      end
    end

    puts ""
    
    # YAML ファイルとして出力
    yaml_path = 'config/generated.yml'
    FileUtils.mkdir_p('config')
    File.write(yaml_path, resolved_config.to_yaml)
    puts "設定ファイルを生成しました: #{yaml_path}"
    
    # JSON ファイルとしても出力
    json_path = 'config/generated.json'
    File.write(json_path, JSON.pretty_generate(resolved_config))
    puts "設定ファイルを生成しました: #{json_path}"
    puts ""
  end

  desc '設定式の妥当性を検証'
  task :validate do
    puts "設定式を検証します..."
    puts ""

    # 検証対象の設定式
    config_expressions = {
      'valid_arithmetic' => '10 + 20 * 2',
      'valid_with_parens' => '(10 + 20) * 2',
      'valid_division' => '100 / 5',
      'invalid_syntax' => '10 +',
      'invalid_division_by_zero' => '10 / 0',
      'valid_variable_ref' => 'let x = 10\nx * 2'
    }

    results = {
      valid: [],
      invalid: []
    }

    config_expressions.each do |name, expression|
      begin
        result = Redex::Interpreter.evaluate(expression)
        results[:valid] << {
          name: name,
          expression: expression,
          result: result[:result]
        }
        puts "  ✓ #{name}: #{expression} => #{result[:result]}"
      rescue Redex::SyntaxError, Redex::NameError, Redex::EvaluationError => e
        results[:invalid] << {
          name: name,
          expression: expression,
          error: e.class.name.split('::').last,
          message: e.message
        }
        puts "  ✗ #{name}: #{expression}"
        puts "    エラー: #{e.message}"
      end
    end

    puts ""
    puts "検証結果:"
    puts "  有効: #{results[:valid].length} 件"
    puts "  無効: #{results[:invalid].length} 件"
    puts ""

    if results[:invalid].any?
      puts "警告: 無効な設定式が見つかりました"
      exit 1
    else
      puts "すべての設定式が有効です"
    end
  end

  desc '現在の設定値を表示'
  task :show do
    yaml_path = 'config/generated.yml'
    
    unless File.exist?(yaml_path)
      puts "設定ファイルが見つかりません: #{yaml_path}"
      puts "まず 'rake config:generate' を実行してください"
      exit 1
    end

    puts "現在の設定値:"
    puts ""
    
    config = YAML.load_file(yaml_path)
    puts config.to_yaml
  end

  desc '環境変数から設定値を計算'
  task :from_env do
    puts "環境変数から設定値を計算します..."
    puts ""

    # 環境変数をパースして context を構築
    env_context = {}
    
    # 特定のプレフィックスを持つ環境変数を抽出
    ENV.select { |k, _v| k.start_with?('REDEX_') }.each do |key, value|
      # REDEX_ プレフィックスを除去
      name = key.sub(/^REDEX_/, '').downcase
      
      # 数値に変換を試みる
      env_context[name] = if value =~ /^\d+$/
                            value.to_i
                          elsif value =~ /^\d+\.\d+$/
                            value.to_f
                          else
                            value
                          end
    end

    puts "環境変数から取得した context:"
    env_context.each { |k, v| puts "  #{k} = #{v}" }
    puts ""

    # 環境変数ベースの設定式
    config_expressions = {
      'workers' => 'workers_base * scale_factor',
      'timeout' => 'timeout_base + latency_buffer'
    }

    # デフォルト値を resolver で提供
    default_resolver = lambda do |name, _ctx|
      defaults = {
        'workers_base' => 4,
        'scale_factor' => 2,
        'timeout_base' => 30,
        'latency_buffer' => 10
      }
      defaults[name]
    end

    puts "計算結果:"
    config_expressions.each do |key, expression|
      begin
        result = Redex::Interpreter.evaluate(
          expression,
          context: env_context,
          ruby_resolver: default_resolver
        )
        puts "  #{key}: #{expression} => #{result[:result]}"
        puts "    出所: #{result[:provenance].inspect}"
      rescue Redex::SyntaxError, Redex::NameError, Redex::EvaluationError => e
        puts "  #{key}: エラー - #{e.message}"
      end
    end
    puts ""
    puts "ヒント: REDEX_WORKERS_BASE=8 のように環境変数を設定できます"
  end
end

# 使用例を表示するタスク
namespace :examples do
  desc 'Redex の Rake タスク統合例を表示'
  task :rake_integration do
    puts <<~USAGE
      ====================================
      Redex Rake タスク統合例
      ====================================
      
      利用可能なタスク:
      
      1. 設定ファイル生成
         $ bundle exec rake config:generate
         
         システム情報（CPU コア数など）から設定値を計算し、
         YAML/JSON ファイルとして出力します。
      
      2. 設定式の検証
         $ bundle exec rake config:validate
         
         設定式の構文と評価可能性を検証します。
         CI/CD パイプラインでの使用に適しています。
      
      3. 設定値の表示
         $ bundle exec rake config:show
         
         生成済みの設定ファイルを表示します。
      
      4. 環境変数からの計算
         $ REDEX_WORKERS_BASE=8 REDEX_SCALE_FACTOR=3 bundle exec rake config:from_env
         
         環境変数を context として使用し、設定値を計算します。
      
      ====================================
      実用例:
      ====================================
      
      # デプロイ前の設定値生成
      $ bundle exec rake config:generate
      $ bundle exec rake config:validate
      $ git add config/generated.yml
      $ git commit -m "Update generated config"
      
      # 環境ごとの設定
      $ REDEX_SCALE_FACTOR=1 bundle exec rake config:from_env  # development
      $ REDEX_SCALE_FACTOR=5 bundle exec rake config:from_env  # production
      
      ====================================
    USAGE
  end
end
