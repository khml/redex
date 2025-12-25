require 'spec_helper'
require_relative '../lib/redex/parser'

RSpec.describe Redex::Parser do
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

  it 'respects operator precedence' do
    ast = Redex::Parser.parse('1 + 2 * 3')
    expect(ast[:type]).to eq(:binary)
    expect(ast[:op]).to eq('+')
    expect(ast[:right][:type]).to eq(:binary)
    expect(ast[:right][:op]).to eq('*')
  end
end
