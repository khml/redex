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
        # 改行は文区切りとしてトークン化する（\n のみを対象）
        if input[i] == "\n"
          tokens << Token.new(:newline, "\n")
          i += 1
          next
        end

        case input[i]
        when /\s/
          # 空白は無視（改行は上で扱っているためここではその他の空白）
          i += 1
          next
        when /[0-9]/
          # 数字リテラル（整数および浮動小数点対応）
          start = i
          # 整数部
          i += 1 while i < input.length && input[i] =~ /[0-9]/
          # 小数部が続く場合（'.' の次が数字であることを確認）
          if i < input.length && input[i] == '.' && (i + 1) < input.length && input[i + 1] =~ /[0-9]/
            i += 1 # '.' を含める
            i += 1 while i < input.length && input[i] =~ /[0-9]/
          end
          num_str = input[start...i]
          # 小数点を含む場合は Float、それ以外は Integer として返す
          val = num_str.include?('.') ? num_str.to_f : num_str.to_i
          tokens << Token.new(:number, val)
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
