# frozen_string_literal: true

require_relative 'spec_helper'

# サンプルアプリケーションの動作確認用テスト
#
# テスト観点:
# - 各サンプルスクリプトが正しく読み込めること
# - サンプルで使用されている主要な機能が動作すること
# - エラーハンドリングが適切に行われること

RSpec.describe 'Examples' do
  describe 'CLI Calculator' do
    # テスト観点: CLI 電卓アプリの主要機能が動作すること

    let(:cli_calculator_path) { File.expand_path('../examples/cli_calculator.rb', __dir__) }

    it 'ファイルが存在すること' do
      expect(File.exist?(cli_calculator_path)).to be true
    end

    it 'ファイルが読み込めること' do
      # 構文エラーがないことを確認
      expect { load cli_calculator_path }.not_to raise_error
    end

    it 'CliCalculatorクラスが定義されていること' do
      load cli_calculator_path
      expect(defined?(CliCalculator)).to eq('constant')
    end

    it 'ワンショット評価が動作すること' do
      load cli_calculator_path
      calculator = CliCalculator.new

      # 標準出力をキャプチャ
      output = StringIO.new
      $stdout = output

      begin
        calculator.evaluate_once('1 + 2 * 3')
        expect(output.string).to include('結果: 7')
      ensure
        $stdout = STDOUT
      end
    end

    it 'エラーハンドリングが動作すること' do
      load cli_calculator_path
      calculator = CliCalculator.new

      # 構文エラーで exit することを確認
      expect {
        calculator.evaluate_once('1 +')
      }.to raise_error(SystemExit)
    end
  end

  describe 'Context and Resolver Examples' do
    # テスト観点: context と ruby_resolver のサンプルが動作すること

    let(:context_resolver_path) { File.expand_path('../examples/context_and_resolver.rb', __dir__) }

    it 'ファイルが存在すること' do
      expect(File.exist?(context_resolver_path)).to be true
    end

    it 'context を使った評価が動作すること' do
      app_config = {
        'max_users' => 100,
        'timeout' => 30,
        'retry_count' => 3
      }

      expression = 'max_users * retry_count'
      result = Redex::Interpreter.evaluate(expression, context: app_config)

      expect(result[:result]).to eq(300)
      expect(result[:provenance][:max_users]).to eq('context')
      expect(result[:provenance][:retry_count]).to eq('context')
    end

    it 'ruby_resolver を使った動的値の解決が動作すること' do
      dynamic_resolver = lambda do |name, _ctx|
        case name
        when 'current_hour'
          12 # テスト用の固定値
        when 'pi'
          3.14159
        else
          nil
        end
      end

      expression = 'current_hour + 10'
      result = Redex::Interpreter.evaluate(expression, ruby_resolver: dynamic_resolver)

      expect(result[:result]).to eq(22)
      expect(result[:provenance][:current_hour]).to eq('ruby_resolver')
    end

    it 'context と ruby_resolver の併用が動作すること' do
      static_config = {
        'base_price' => 1000,
        'tax_rate' => 10
      }

      user_resolver = lambda do |name, _ctx|
        name == 'user_discount' ? 15 : nil
      end

      expression = '(base_price - user_discount) * (100 + tax_rate) / 100'
      result = Redex::Interpreter.evaluate(
        expression,
        context: static_config,
        ruby_resolver: user_resolver
      )

      expect(result[:result]).to eq(1083)
      expect(result[:provenance][:base_price]).to eq('context')
      expect(result[:provenance][:user_discount]).to eq('ruby_resolver')
    end

    it '解決の優先順位が正しいこと（スクリプト内定義 > context > ruby_resolver）' do
      context_with_x = { 'x' => 100 }
      resolver_with_x = ->(name, _ctx) { name == 'x' ? 999 : nil }

      expression = "let x = 10\nx * 2"
      result = Redex::Interpreter.evaluate(
        expression,
        context: context_with_x,
        ruby_resolver: resolver_with_x
      )

      # スクリプト内の let が最優先
      expect(result[:result]).to eq(20)
    end
  end

  describe 'Sinatra Demo' do
    # テスト観点: Sinatra サンプルが読み込めること（Sinatra のインストールは任意）

    let(:sinatra_demo_path) { File.expand_path('../examples/sinatra_demo.rb', __dir__) }

    it 'ファイルが存在すること' do
      expect(File.exist?(sinatra_demo_path)).to be true
    end

    it 'Sinatra がなくても適切なエラーメッセージが表示されること' do
      # Sinatra がインストールされていない場合のテスト
      # このテストは Sinatra がインストールされている場合はスキップ
      begin
        require 'sinatra'
        skip 'Sinatra is installed'
      rescue LoadError
        output = StringIO.new
        $stdout = output

        begin
          expect {
            load sinatra_demo_path
          }.to raise_error(SystemExit)
          expect(output.string).to include('Sinatra がインストールされていません')
        ensure
          $stdout = STDOUT
        end
      end
    end

    it 'Redex の API レスポンス形式をテストできること' do
      # Sinatra の実際の起動は行わず、レスポンス形式のみテスト
      expression = '1 + 2 * 3'
      context = { 'x' => 10, 'y' => 5 }

      result = Redex::Interpreter.evaluate(expression, context: context)

      # 期待される JSON レスポンスの形式
      response = {
        success: true,
        result: result[:result],
        environment: result[:env],
        provenance: result[:provenance],
        expression: expression
      }

      expect(response[:success]).to be true
      expect(response[:result]).to eq(7)
    end

    it 'エラー時のレスポンス形式をテストできること' do
      expression = '1 +'

      error_response = nil
      begin
        Redex::Interpreter.evaluate(expression)
      rescue Redex::SyntaxError => e
        error_response = {
          success: false,
          error: 'SyntaxError',
          message: e.message,
          expression: expression
        }
      end

      expect(error_response).not_to be_nil
      expect(error_response[:success]).to be false
      expect(error_response[:error]).to eq('SyntaxError')
    end
  end

  describe 'Rake Task Integration' do
    # テスト観点: Rake タスクのサンプルが動作すること

    let(:rake_task_path) { File.expand_path('../examples/rake_task.rb', __dir__) }

    it 'ファイルが存在すること' do
      expect(File.exist?(rake_task_path)).to be true
    end

    it 'ファイルが読み込めること' do
      # Rake の namespace が必要なため、構文チェックのみ
      content = File.read(rake_task_path)
      expect(content).to include('namespace :config')
      expect(content).to include('Redex::Interpreter.evaluate')
    end

    it 'システム情報を使った設定値計算が動作すること' do
      # サンプルで使われているロジックのテスト
      system_resolver = lambda do |name, _ctx|
        case name
        when 'cpu_cores'
          4
        when 'available_memory'
          8192
        when 'base_timeout'
          30
        else
          nil
        end
      end

      # 設定式の例
      config_expressions = {
        'pool_size' => 'cpu_cores * 5',
        'timeout' => 'base_timeout + 10',
        'cache_size_mb' => 'available_memory / 8'
      }

      context = {}
      results = {}

      config_expressions.each do |key, expression|
        result = Redex::Interpreter.evaluate(
          expression,
          context: context,
          ruby_resolver: system_resolver
        )
        results[key] = result[:result]
        context[key] = result[:result]
      end

      expect(results['pool_size']).to eq(20)
      expect(results['timeout']).to eq(40)
      expect(results['cache_size_mb']).to eq(1024)
    end

    it '環境変数からの設定計算が動作すること' do
      env_context = {
        'workers_base' => 8,
        'scale_factor' => 3
      }

      default_resolver = lambda do |name, _ctx|
        defaults = {
          'workers_base' => 4,
          'scale_factor' => 2
        }
        defaults[name]
      end

      expression = 'workers_base * scale_factor'
      result = Redex::Interpreter.evaluate(
        expression,
        context: env_context,
        ruby_resolver: default_resolver
      )

      # context の値が優先される
      expect(result[:result]).to eq(24)
      expect(result[:provenance][:workers_base]).to eq('context')
    end

    it '設定式の検証が動作すること' do
      valid_expressions = {
        'valid_arithmetic' => '10 + 20 * 2',
        'valid_with_parens' => '(10 + 20) * 2',
        'valid_division' => '100 / 5'
      }

      invalid_expressions = {
        'invalid_syntax' => '10 +',
        'invalid_division_by_zero' => '10 / 0'
      }

      # 有効な式は正常に評価される
      valid_expressions.each do |name, expression|
        expect {
          Redex::Interpreter.evaluate(expression)
        }.not_to raise_error
      end

      # 無効な式はエラーが発生する
      expect {
        Redex::Interpreter.evaluate(invalid_expressions['invalid_syntax'])
      }.to raise_error(Redex::SyntaxError)

      expect {
        Redex::Interpreter.evaluate(invalid_expressions['invalid_division_by_zero'])
      }.to raise_error(Redex::EvaluationError)
    end
  end

  describe 'Examples Integration' do
    # テスト観点: サンプル間の一貫性と統合性

    it 'すべてのサンプルファイルが存在すること' do
      examples = [
        'cli_calculator.rb',
        'context_and_resolver.rb',
        'sinatra_demo.rb',
        'rake_task.rb'
      ]

      examples.each do |example|
        path = File.expand_path("../examples/#{example}", __dir__)
        expect(File.exist?(path)).to be(true), "#{example} が見つかりません"
      end
    end

    it '全サンプルで同じ Redex API が使用されていること' do
      # 基本的な API の一貫性を確認
      expression = "let x = 10\nx + 5"

      # context なし
      result1 = Redex::Interpreter.evaluate(expression)
      expect(result1[:result]).to eq(15)

      # context あり
      result2 = Redex::Interpreter.evaluate('x + 5', context: { 'x' => 10 })
      expect(result2[:result]).to eq(15)

      # ruby_resolver あり
      resolver = ->(name, _ctx) { name == 'x' ? 10 : nil }
      result3 = Redex::Interpreter.evaluate('x + 5', ruby_resolver: resolver)
      expect(result3[:result]).to eq(15)

      # すべてのレスポンスに必須フィールドが含まれること
      [result1, result2, result3].each do |result|
        expect(result).to have_key(:result)
        expect(result).to have_key(:env)
        expect(result).to have_key(:provenance)
      end
    end

    it 'サンプルで示されているエラーハンドリングパターンが一貫していること' do
      # 各種エラーが適切に発生すること
      expect {
        Redex::Interpreter.evaluate('1 +')
      }.to raise_error(Redex::SyntaxError)

      expect {
        Redex::Interpreter.evaluate('undefined_var')
      }.to raise_error(Redex::NameError)

      expect {
        Redex::Interpreter.evaluate('1 / 0')
      }.to raise_error(Redex::EvaluationError)

      expect {
        Redex::Interpreter.evaluate("const x = 1\nlet x = 2")
      }.to raise_error(Redex::EvaluationError)
    end
  end
end
