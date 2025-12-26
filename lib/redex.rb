require_relative "redex/version"

module Redex
  # Core namespace for the Redex project
  
  # 構文エラー（パース時の構文エラー）
  class SyntaxError < StandardError; end
  
  # 名前解決エラー（未定義の識別子など）
  class NameError < StandardError; end
  
  # 評価エラー（実行時エラー：ゼロ除算、型エラー、const再代入など）
  class EvaluationError < StandardError; end
  
  # 高レベルインタープリタ API
  class Interpreter
    # ソースコードを評価します
    #
    # @param source [String] 評価するソースコード
    # @param context [Hash] 事前定義された変数/定数のハッシュ（省略可能）
    # @param ruby_resolver [Proc, nil] 未解決識別子を解決するコールバック（省略可能）
    # @return [Hash] 評価結果の詳細情報（:result, :env, :provenance, :errors, :diagnostics, :meta）
    # @raise [Redex::SyntaxError] 構文エラー時
    # @raise [Redex::NameError] 未定義の識別子を参照した場合
    # @raise [Redex::EvaluationError] 評価エラー時
    def self.evaluate(source, context: {}, ruby_resolver: nil)
      require_relative 'redex/parser'
      require_relative 'redex/evaluator'
      
      # パース
      ast = Parser.parse(source)
      
      # 評価
      Evaluator.evaluate(ast, {}, context: context, ruby_resolver: ruby_resolver)
    end
  end
end
