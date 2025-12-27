require 'spec_helper'
require_relative '../lib/redex'

RSpec.describe 'Multi-line processing' do
  # 観点: 複数行ソースを上から順に評価し、最終行の評価結果を返す
  # 説明: 2つの let 宣言と加算式を含む複数行ソースが正しく評価されること
  it 'evaluates multiple lines sequentially' do
    src = "let a = 1\nlet b = 2\na + b\n"
    res = Redex::Interpreter.evaluate(src)
    expect(res[:result]).to eq(3)
    expect(res[:env][:a]).to eq(1)
    expect(res[:env][:b]).to eq(2)
  end

  # 観点: 空行を無視して評価が継続されること
  # 説明: 空行を挟んだ複数行ソースでも最終的な結果が変わらないこと
  it 'ignores empty lines' do
    src = "let a = 1\n\nlet b = 2\n\na + b\n"
    res = Redex::Interpreter.evaluate(src)
    expect(res[:result]).to eq(3)
  end

  # 観点: 最終行の末尾改行がなくても複数行入力を受け付けること
  # 説明: 改行無しの最終行を含むソースが正しく評価されること
  it 'accepts multi-line input without trailing newline' do
    src = "let a = 1\n1 + 2" # no trailing newline
    res = Redex::Interpreter.evaluate(src)
    expect(res[:result]).to eq(3)
    expect(res[:env][:a]).to eq(1)
  end
end
