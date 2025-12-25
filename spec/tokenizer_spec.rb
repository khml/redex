require 'spec_helper'
require_relative '../lib/redex/tokenizer'

RSpec.describe Redex::Tokenizer do
  it 'tokenizes let assignment' do
    toks = Redex::Tokenizer.tokenize('let x = 42 + y')
    types = toks.map(&:type)
    values = toks.map(&:value)
    expect(types).to eq([:keyword, :ident, :op, :number, :op, :ident])
    expect(values).to eq(%w[let x = 42 + y].map { |v| v =~ /\A[0-9]+\z/ ? v.to_i : v })
  end
end
