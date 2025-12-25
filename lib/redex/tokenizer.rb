# frozen_string_literal: true

require_relative '../redex'

module Redex
  # 空白区切りの簡易トークナイザ
  #
  # 数字リテラル、識別子、キーワード(`let`, `const`)、演算子、括弧などを
  # 単純に分割して `Token = Struct.new(:type, :value)` の配列を返します。
  class Tokenizer
    # トークン構造体 (`type`, `value`)
    Token = Struct.new(:type, :value)

    # 認識するキーワード
    KEYWORDS = %w[let const].freeze
    # 単一文字演算子
    OPERATORS = %w[+ - * / =].freeze

    # 入力文字列をトークン列に変換します。
    #
    # @param input [String] パース対象の入力文字列
    # @return [Array<Token>] トークンの配列（順序は入力順）
    def self.tokenize(input)
      tokens = []
      i = 0
      while i < input.length
        case input[i]
        when /\s/
          # 空白は無視
          i += 1
          next
        when /[0-9]/
          # 数字リテラル（整数のみ対応）
          start = i
          i += 1 while i < input.length && input[i] =~ /[0-9]/
          tokens << Token.new(:number, input[start...i].to_i)
          next
        when /[A-Za-z_]/
          # 識別子またはキーワード
          start = i
          i += 1 while i < input.length && input[i] =~ /[A-Za-z0-9_]/
          s = input[start...i]
          if KEYWORDS.include?(s)
            tokens << Token.new(:keyword, s)
          else
            tokens << Token.new(:ident, s)
          end
          next
        else
          ch = input[i]
          if OPERATORS.include?(ch)
            tokens << Token.new(:op, ch)
            i += 1
            next
          end
          if ch == '('
            tokens << Token.new(:lparen, ch)
            i += 1
            next
          end
          if ch == ')'
            tokens << Token.new(:rparen, ch)
            i += 1
            next
          end
          # 未知の文字は unknown トークンとして扱う
          tokens << Token.new(:unknown, ch)
          i += 1
        end
      end
      tokens
    end
  end
end
