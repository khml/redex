require 'spec_helper'
require_relative '../lib/redex/tokenizer'

RSpec.describe Redex::Tokenizer do
  # 'let' 宣言のトークン分解を検証するテスト
  # 観点: キーワード、識別子、代入演算子、数値、演算子、識別子が期待通りに分割されること
  it 'tokenizes let assignment' do
    toks = Redex::Tokenizer.tokenize('let x = 42 + y')
    types = toks.map(&:type)
    values = toks.map(&:value)
    expect(types).to eq([:keyword, :ident, :op, :number, :op, :ident])
    expect(values).to eq(%w[let x = 42 + y].map { |v| v =~ /\A[0-9]+\z/ ? v.to_i : v })
  end

  # 空入力の境界値テスト
  # 観点: 空文字列でトークン配列が空であること
  it 'returns empty array for empty input' do
    expect(Redex::Tokenizer.tokenize('')).to eq([])
  end

  # 括弧と余分な空白の処理
  # 観点: 空白は無視され、括弧と識別子が正しくトークン化されること
  it 'handles parentheses and spaces' do
    toks = Redex::Tokenizer.tokenize(' (  foo  ) ')
    expect(toks.map(&:type)).to eq([:lparen, :ident, :rparen])
    expect(toks.map(&:value)).to eq(['(', 'foo', ')'])
  end

  # 未知文字（非認識文字）の取扱いテスト
  # 観点: 認識できない単一文字は `:unknown` トークンとして返ること、値が正しいことを確認する
  it 'produces :unknown for unrecognized single characters' do
    toks = Redex::Tokenizer.tokenize('x $ 3')
    expect(toks.map(&:type)).to include(:unknown)
    unknown = toks.find { |t| t.type == :unknown }
    expect(unknown.value).to eq('$')
  end

  # 非ASCII文字を識別子と見なさない仕様の境界テスト
  # 観点: ギリシャ文字など非ASCII文字は `:ident` ではなく `:unknown` になることを検証する
  it 'treats non-ASCII letters as unknown' do
    toks = Redex::Tokenizer.tokenize('α = 1')
    types = toks.map(&:type)
    # 'α' は ASCII の識別子パターンに一致しないため :unknown になる
    expect(types).to include(:unknown, :op, :number)
  end

  # 連続演算子と複数空白の処理
  # 観点: 複合演算子を結合せず、それぞれが個別の `:op` トークンとして返ること。空白は無視されること
  it 'handles consecutive operators and multiple spaces' do
    toks = Redex::Tokenizer.tokenize('a  +   - b')
    expect(toks.map(&:type)).to eq([:ident, :op, :op, :ident])
    expect(toks.map(&:value)).to eq(['a', '+', '-', 'b'])
  end

  # 浮動小数点リテラルのトークナイズ
  # 観点: 小数点を含む数値リテラルが `:number` トークンとして返り、
  #       値が Float として格納されることを検証する
  it 'tokenizes float literals' do
    toks = Redex::Tokenizer.tokenize('3.14 + x')
    expect(toks.map(&:type)).to eq([:number, :op, :ident])
    expect(toks.map(&:value)).to eq([3.14, '+', 'x'])
  end
end
