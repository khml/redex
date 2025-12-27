#!/usr/bin/env ruby
# frozen_string_literal: true

# CLI 電卓アプリケーション
#
# Redex ライブラリを使った対話型計算機の例。
# 標準入力から式を受け取り、評価結果を表示します。
#
# 使い方:
#   ruby examples/cli_calculator.rb              # 対話モード
#   ruby examples/cli_calculator.rb "1 + 2 * 3"  # ワンショット評価
#   echo "let x = 10\nx * 2" | ruby examples/cli_calculator.rb  # パイプ入力
#
# セキュリティ注意:
#   ruby_resolver を有効にすると任意の Ruby コードが実行可能になります。
#   信頼できない入力には使用しないでください。

require_relative '../lib/redex'

# CLI 電卓クラス
class CliCalculator
  def initialize
    @history = []
    @session_env = {}
  end

  # ワンショットモード: 引数で渡された式を評価
  def evaluate_once(expression)
    puts "入力: #{expression}"
    result = evaluate_expression(expression)
    display_result(result)
  rescue Redex::SyntaxError, Redex::NameError, Redex::EvaluationError => e
    puts "エラー: #{e.message}"
    exit 1
  end

  # 対話モード: REPLを起動
  def repl
    puts "Redex CLI 電卓 - 対話モード"
    puts "式を入力してください (終了: exit, quit, Ctrl+D)"
    puts "コマンド: history (履歴表示), clear (環境リセット), help (ヘルプ)"
    puts ""

    loop do
      print "> "
      input = gets
      break if input.nil? # Ctrl+D

      input = input.strip
      next if input.empty?

      case input
      when 'exit', 'quit'
        puts "終了します"
        break
      when 'history'
        show_history
      when 'clear'
        clear_session
      when 'help'
        show_help
      else
        process_input(input)
      end
    end
  end

  # パイプ入力モード: 標準入力から複数行を読み取り
  def evaluate_from_stdin
    input = $stdin.read.strip
    return if input.empty?

    puts "入力:"
    puts input
    puts ""

    result = evaluate_expression(input)
    display_result(result)
  rescue Redex::SyntaxError, Redex::NameError, Redex::EvaluationError => e
    puts "エラー: #{e.message}"
    exit 1
  end

  private

  # 式を評価
  def evaluate_expression(expression)
    # セッション環境を context として渡し、評価後の環境を保持
    result = Redex::Interpreter.evaluate(expression, context: @session_env)
    @session_env.merge!(result[:env]) if result[:env]
    result
  end

  # 結果を表示
  def display_result(result)
    puts "結果: #{result[:result]}"

    # 環境に新しい変数が追加された場合は表示
    if result[:env] && !result[:env].empty?
      puts "環境: #{format_env(result[:env])}"
    end

    # 出所情報がある場合は表示
    if result[:provenance] && !result[:provenance].empty?
      puts "出所: #{result[:provenance].inspect}"
    end
  end

  # 対話モードでの入力処理
  def process_input(input)
    @history << input
    result = evaluate_expression(input)
    puts "=> #{result[:result]}"
  rescue Redex::SyntaxError, Redex::NameError, Redex::EvaluationError => e
    puts "エラー: #{e.message}"
  end

  # 履歴表示
  def show_history
    if @history.empty?
      puts "履歴はありません"
    else
      puts "履歴:"
      @history.each_with_index do |expr, idx|
        puts "  #{idx + 1}. #{expr}"
      end
    end
  end

  # セッション環境をクリア
  def clear_session
    @session_env.clear
    @history.clear
    puts "環境と履歴をクリアしました"
  end

  # ヘルプ表示
  def show_help
    puts <<~HELP
      Redex CLI 電卓 - ヘルプ
      
      基本的な使い方:
        1 + 2 * 3          # 算術式
        (1 + 2) * 3        # 括弧を使った式
        let x = 10         # 変数定義
        const pi = 3       # 定数定義
        x + pi             # 変数の参照
      
      コマンド:
        history            # 入力履歴を表示
        clear              # 環境と履歴をクリア
        help               # このヘルプを表示
        exit, quit         # 終了
      
      サポートされる演算:
        +, -, *, /         # 四則演算
        ( )                # 括弧
      
      注意:
        - 定数は再代入できません
        - 整数と浮動小数点数をサポート
    HELP
  end

  # 環境をフォーマット
  def format_env(env)
    env.map { |k, v| "#{k}=#{v}" }.join(', ')
  end
end

# メイン処理
if __FILE__ == $PROGRAM_NAME
  calculator = CliCalculator.new

  if ARGV.length > 0
    # 引数モード: コマンドライン引数を評価
    calculator.evaluate_once(ARGV.join(' '))
  elsif !$stdin.tty?
    # パイプ入力モード: 標準入力から読み取り
    calculator.evaluate_from_stdin
  else
    # 対話モード: REPL
    calculator.repl
  end
end
