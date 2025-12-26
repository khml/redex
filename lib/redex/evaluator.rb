# frozen_string_literal: true

require_relative '../redex'

module Redex
  # 単純な AST 評価器
  # - AST は現在ハッシュで表現される（Parser の出力）
  # - 簡易な環境（Hash）を受け取り、識別子解決と let/const 宣言を行う
  class Evaluator
    class EvalError < StandardError; end

    def initialize(env = {})
      @env = env
    end

    def eval(node)
      case node[:type]
      when :number
        node[:value]
      when :ident
        name = node[:name]
        raise EvalError, "undefined variable #{name}" unless @env.key?(name)
        @env[name]
      when :binary
        l = eval(node[:left])
        r = eval(node[:right])
        case node[:op]
        when '+' then l + r
        when '-' then l - r
        when '*' then l * r
        when '/' then
          raise EvalError, 'division by zero' if r == 0
          l / r
        else
          raise EvalError, "unknown op #{node[:op]}"
        end
      when :let, :const
        val = eval(node[:value])
        @env[node[:name]] = val
        val
      else
        raise EvalError, "unknown node type #{node[:type]}"
      end
    end

    # クラスメソッド呼び出しの便宜ラッパー
    # @param node [Hash] AST ノード
    # @param env [Hash] 評価環境（キーはシンボル）
    # @return [Numeric] 評価結果
    def self.evaluate(node, env = {})
      new(env).eval(node)
    end
  end
end
