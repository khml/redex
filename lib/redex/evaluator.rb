# frozen_string_literal: true

require 'set'
require_relative '../redex'

module Redex
  # 単純な AST 評価器
  # - AST は現在ハッシュで表現される（Parser の出力）
  # - 簡易な環境（Hash）を受け取り、識別子解決と let/const 宣言を行う
  # - const の再代入を検出し、context の値が数値であることを検証する
  class Evaluator
    # EvalError は Redex::EvaluationError のエイリアスとして扱う
    # 既存のコードとの互換性のために残す
    EvalError = Redex::EvaluationError

    # 評価器の初期化
    #
    # @param env [Hash] 初期環境（変数名 => 値のハッシュ）
    # @param context [Hash] 外部から提供される初期値（変数名 => 値）
    # @param ruby_resolver [Proc, nil] 未解決識別子や ruby: プレフィックスを解決するコールバック
    def initialize(env = {}, context: {}, ruby_resolver: nil)
      @env = env.dup
      @context = context.dup
      @ruby_resolver = ruby_resolver
      @const_names = Set.new  # const で定義された名前を追跡
      @provenance = {}  # 各識別子の出所を記録（'script', 'context', 'ruby_resolver'）
      
      # context の検証：すべての値が数値であることを確認
      validate_context!
      
      # context の値を provenance に記録
      @context.each_key do |name|
        @provenance[name.to_sym] = 'context'
      end
    end

    # AST ノードを評価します
    #
    # @param node [Hash] AST ノード
    # @return [Numeric] 評価結果
    # @raise [Redex::EvaluationError] 評価エラー時
    # @raise [Redex::NameError] 未定義の識別子を参照した場合
    def eval(node)
      case node[:type]
      when :number
        node[:value]
      when :ident
        resolve_identifier(node[:name])
      when :binary
        l = eval(node[:left])
        r = eval(node[:right])
        case node[:op]
        when '+' then l + r
        when '-' then l - r
        when '*' then l * r
        when '/' then
          raise EvaluationError, 'division by zero' if r == 0
          l / r
        else
          raise EvaluationError, "unknown op #{node[:op]}"
        end
      when :let, :const
        name = node[:name]
        
        # const の再代入チェック
        if @const_names.include?(name)
          raise EvaluationError, "cannot reassign to const #{name}"
        end
        
        val = eval(node[:value])
        
        # 値が数値であることを検証
        unless val.is_a?(Numeric)
          raise EvaluationError, "assigned value must be numeric, got #{val.class}"
        end
        
        @env[name] = val
        @provenance[name] = 'script'
        
        # const の場合は追跡セットに追加
        if node[:type] == :const || node[:kind] == :const
          @const_names.add(name)
        end
        
        val
      else
        raise EvaluationError, "unknown node type #{node[:type]}"
      end
    end

    # クラスメソッド呼び出しの便宜ラッパー
    #
    # @param node [Hash] AST ノード
    # @param env [Hash] 評価環境（キーはシンボル）
    # @param context [Hash] 外部から提供される初期値
    # @param ruby_resolver [Proc, nil] 未解決識別子を解決するコールバック
    # @return [Hash] 評価結果の詳細情報
    def self.evaluate(node, env = {}, context: {}, ruby_resolver: nil)
      evaluator = new(env, context: context, ruby_resolver: ruby_resolver)
      result = nil
      if node.is_a?(Array)
        node.each do |n|
          result = evaluator.eval(n)
        end
      else
        result = evaluator.eval(node)
      end
      
      # 詳細な戻り値を構築
      {
        result: result,
        env: evaluator.env,
        provenance: evaluator.provenance,
        errors: [],
        diagnostics: [],
        meta: { version: Redex::VERSION }
      }
    end

    # 評価環境を取得（外部公開用）
    #
    # @return [Hash] 現在の評価環境
    def env
      @env.dup
    end

    # provenance 情報を取得（外部公開用）
    #
    # @return [Hash] 識別子の出所情報
    def provenance
      @provenance.dup
    end

    private

    # context の値がすべて数値であることを検証
    #
    # @raise [Redex::EvaluationError] 非数値の値が含まれている場合
    def validate_context!
      @context.each do |key, value|
        unless value.is_a?(Numeric)
          raise EvaluationError, "context value for '#{key}' must be numeric, got #{value.class}"
        end
      end
    end

    # 識別子を解決します（優先順位: env > context > ruby_resolver）
    #
    # @param name [Symbol] 識別子名
    # @return [Numeric] 解決された値
    # @raise [Redex::NameError] 解決できない場合
    def resolve_identifier(name)
      # 1. スクリプト内で定義された名前を優先
      return @env[name] if @env.key?(name)
      
      # 2. context で提供された値
      if @context.key?(name) || @context.key?(name.to_s)
        key = @context.key?(name) ? name : name.to_s
        return @context[key]
      end
      
      # 3. ruby_resolver で解決を試みる
      if @ruby_resolver
        begin
          # 現在のコンテキストを合成して渡す
          current_context = @context.merge(@env)
          result = @ruby_resolver.call(name.to_s, current_context)
          
          # nil または非数値の場合はエラー
          if result.nil?
            raise NameError, "undefined variable #{name}"
          elsif !result.is_a?(Numeric)
            raise EvaluationError, "ruby_resolver must return numeric value, got #{result.class}"
          end
          
          # provenance を記録
          @provenance[name] = 'ruby_resolver' unless @provenance.key?(name)
          
          return result
        rescue StandardError => e
          # ruby_resolver 内でのエラーは伝播
          raise e if e.is_a?(Redex::NameError) || e.is_a?(Redex::EvaluationError)
          raise EvaluationError, "ruby_resolver error: #{e.message}"
        end
      end
      
      # 解決できない場合
      raise NameError, "undefined variable #{name}"
    end
  end
end
