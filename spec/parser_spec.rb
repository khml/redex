require 'spec_helper'
require_relative '../lib/redex/parser'

RSpec.describe Redex::Parser do
  # let 宣言と二項演算の組合せをパースできること
  # 観点: キーワード、識別子、等号、右辺の式が正しく AST に変換されること
  it 'parses let with binary expression' do
    ast = Redex::Parser.parse('let x = 1 + 2')
    expect(ast[:type]).to eq(:let)
    expect(ast[:name]).to eq(:x)
    expect(ast[:value]).to be_a(Hash)
    expect(ast[:value][:type]).to eq(:binary)
    expect(ast[:value][:op]).to eq('+')
    expect(ast[:value][:left][:type]).to eq(:number)
    expect(ast[:value][:right][:type]).to eq(:number)
  end

  # 演算子の優先度が守られること
  # 観点: '*' は '+' より優先され、AST の右側に '*' ノードが来ること
  it 'respects operator precedence' do
    ast = Redex::Parser.parse('1 + 2 * 3')
    expect(ast[:type]).to eq(:binary)
    expect(ast[:op]).to eq('+')
    expect(ast[:right][:type]).to eq(:binary)
    expect(ast[:right][:op]).to eq('*')
  end

  # 括弧によるグルーピングが優先されること
  # 観点: '(1 + 2) * 3' は左側が '+' のサブツリーになること
  it 'parses parentheses grouping' do
    ast = Redex::Parser.parse('(1 + 2) * 3')
    expect(ast[:type]).to eq(:binary)
    expect(ast[:op]).to eq('*')
    expect(ast[:left][:type]).to eq(:binary)
    expect(ast[:left][:op]).to eq('+')
  end

  # 識別子単体がプライマリ式としてパースされること
  # 観点: 単一の識別子 'x' が ident ノードとして返ること
  it 'parses identifier primary' do
    ast = Redex::Parser.parse('x')
    expect(ast[:type]).to eq(:ident)
    expect(ast[:name]).to eq(:x)
  end

  # トークン配列を直接渡してパースできること
  # 観点: Tokenizer の出力をそのまま `parse` に渡して同等の AST が得られること
  it 'accepts token array input' do
    tokens = Redex::Tokenizer.tokenize('1 + 2')
    ast = Redex::Parser.parse(tokens)
    expect(ast[:type]).to eq(:binary)
    expect(ast[:op]).to eq('+')
  end

  # 不完全な入力で終端に達した場合、適切なエラーを返すこと
  # 観点: '1 +' のような入力は `unexpected end` エラーになる
  it 'raises unexpected end for incomplete input' do
    expect { Redex::Parser.parse('1 +') }.to raise_error(Redex::Parser::ParseError, /unexpected end/)
  end

  # let 宣言で期待する '=' がない場合に適切なエラーを返すこと
  # 観点: 'let x 1' のように '=' が欠けている場合に `expected op, got number` を投げる
  it 'raises on expected token mismatch in let' do
    expect { Redex::Parser.parse('let x 1') }.to raise_error(Redex::Parser::ParseError, /expected op, got number/)
  end

  # 未知トークンが入力された場合に適切にエラー化されること
  # 観点: 認識できない単一文字は `:unknown` トークンとなり、`unexpected token unknown` を投げる
  it 'raises on unknown token' do
    expect { Redex::Parser.parse('@') }.to raise_error(Redex::Parser::ParseError, /unexpected token unknown/)
  end
end
