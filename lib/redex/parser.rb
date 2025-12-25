# frozen_string_literal: true

require_relative 'tokenizer'

module Redex
  class Parser
    class ParseError < StandardError; end

    # 文字列またはトークン配列からASTを作成します。
    #
    # @param source [String, Array<Token>] パース対象（文字列の場合はトークナイズされます）
    # @return [Hash] 生成されたASTノード（最上位ノード）
    def self.parse(source)
      tokens = source.is_a?(String) ? Tokenizer.tokenize(source) : source
      new(tokens).parse_program
    end

    # 初期化（内部API）
    #
    # @param tokens [Array<Token>] トークン列（通常は `Tokenizer.tokenize` の結果）
    def initialize(tokens)
      @tokens = tokens.dup
      @pos = 0
    end

    # 現在のトークンを返します（消費はしません）
    #
    # @return [Token, nil] 現在のトークン、存在しない場合はnil
    def current
      @tokens[@pos]
    end

    # 現在のトークンを検証して1つ進めます。
    #
    # @param expected_type [Symbol, nil] 期待するトークン種別（指定しない場合は任意）
    # @return [Token] 消費したトークン
    # @raise [ParseError] 期待したトークンが見つからなかった場合
    def eat(expected_type = nil)
      t = current
      if expected_type && (!t || t.type != expected_type)
        raise ParseError, "expected #{expected_type}, got #{t&.type}"
      end
      @pos += 1
      t
    end

    # プログラムをパースして最上位ノードを返します。
    # 現状は単一の式または文をパースします。
    #
    # @return [Hash] プログラムのAST（トップレベルノード）
    def parse_program
      parse_statement
    end

    # 文（ステートメント）をパースします。
    # 現状は `let`/`const` の宣言か式のどちらかを受け付けます。
    #
    # @return [Hash] 文のASTノード
    def parse_statement
      if current && current.type == :keyword && %w[let const].include?(current.value)
        parse_let
      else
        parse_expression
      end
    end

    # let/const 宣言をパースします。
    #
    # @return [Hash] {:type=>:let, :kind=>:let/:const, :name=>Symbol, :value=>AST}
    # @raise [ParseError] 構文が不正な場合
    def parse_let
      kw = eat(:keyword)
      name = eat(:ident)
      eq = eat(:op)
      raise ParseError, 'expected = in let' unless eq.value == '='
      value = parse_expression
      { type: :let, kind: kw.value.to_sym, name: name.value.to_sym, value: value }
    end

    # Expression parsing with precedence
    # 式をパースします（優先順位を考慮した再帰下降）
    #
    # @return [Hash] 式のASTノード
    def parse_expression
      parse_add_sub
    end

    # 加減算レベルのパーサ（左結合）
    #
    # @return [Hash] 二項演算のASTまたは子ノード
    def parse_add_sub
      node = parse_mul_div
      while current && current.type == :op && %w[+ -].include?(current.value)
        op = eat(:op).value
        right = parse_mul_div
        node = { type: :binary, op: op, left: node, right: right }
      end
      node
    end

    # 乗除算レベルのパーサ（左結合）
    #
    # @return [Hash] 二項演算のASTまたは子ノード
    def parse_mul_div
      node = parse_primary
      while current && current.type == :op && %w[* /].include?(current.value)
        op = eat(:op).value
        right = parse_primary
        node = { type: :binary, op: op, left: node, right: right }
      end
      node
    end

    # 原始要素（数値、識別子、括弧式）をパースします。
    #
    # @return [Hash] 数値ノード、識別子ノード、または括弧内の式ノード
    # @raise [ParseError] 予期しないトークンや入力終端の場合
    def parse_primary
      t = current
      raise ParseError, 'unexpected end' unless t
      case t.type
      when :number
        eat(:number)
        { type: :number, value: t.value }
      when :ident
        eat(:ident)
        { type: :ident, name: t.value.to_sym }
      when :lparen
        eat(:lparen)
        node = parse_expression
        eat(:rparen)
        node
      else
        raise ParseError, "unexpected token #{t.type}"
      end
    end
  end
end
