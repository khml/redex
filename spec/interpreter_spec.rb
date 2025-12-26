require 'spec_helper'
require_relative '../lib/redex'

RSpec.describe Redex::Interpreter do
  # 基本的な式の評価
  # 観点: 簡単な算術式が正しく評価されること
  it 'evaluates simple arithmetic expression' do
    result = Redex::Interpreter.evaluate('1 + 2 * 3')
    expect(result[:result]).to eq(7)
  end

  # context を使用した評価
  # 観点: context で提供された値が識別子として解決されること
  it 'evaluates with context' do
    result = Redex::Interpreter.evaluate('x + 1', context: { 'x' => 2 })
    expect(result[:result]).to eq(3)
    expect(result[:provenance][:x]).to eq('context')
  end

  # ruby_resolver を使用した評価
  # 観点: ruby_resolver が未解決識別子を解決できること
  it 'evaluates with ruby_resolver' do
    resolver = ->(name, _ctx) do
      case name
      when 'y' then 10
      else nil
      end
    end
    
    result = Redex::Interpreter.evaluate('y + 1', ruby_resolver: resolver)
    expect(result[:result]).to eq(11)
    expect(result[:provenance][:y]).to eq('ruby_resolver')
  end

  # context と ruby_resolver の併用
  # 観点: context と ruby_resolver が正しく協調して動作すること
  it 'evaluates with both context and ruby_resolver' do
    resolver = ->(name, _ctx) do
      case name
      when 'z' then 5
      else nil
      end
    end
    
    result = Redex::Interpreter.evaluate(
      'x + z',
      context: { 'x' => 1 },
      ruby_resolver: resolver
    )
    
    # x は context から、z は ruby_resolver から解決される
    expect(result[:result]).to eq(6)
    expect(result[:provenance][:x]).to eq('context')
    expect(result[:provenance][:z]).to eq('ruby_resolver')
  end

  # ruby_resolver が nil を返した場合のエラー
  # 観点: ruby_resolver が nil を返すと未定義変数エラーになること
  it 'raises NameError when ruby_resolver returns nil' do
    resolver = ->(name, _ctx) { nil }
    
    expect {
      Redex::Interpreter.evaluate('undefined_var', ruby_resolver: resolver)
    }.to raise_error(Redex::NameError)
  end

  # 複雑な式の評価
  # 観点: 括弧を含む複雑な式が正しく評価されること
  it 'evaluates complex expression with parentheses' do
    result = Redex::Interpreter.evaluate('(1 + 2) * 3')
    expect(result[:result]).to eq(9)
  end

  # let 宣言
  # 観点: let で変数を定義できること
  it 'evaluates let declaration' do
    result = Redex::Interpreter.evaluate('let x = 10')
    expect(result[:result]).to eq(10)
    expect(result[:env][:x]).to eq(10)
    expect(result[:provenance][:x]).to eq('script')
  end

  # const 宣言
  # 観点: const で定数を定義できること
  it 'evaluates const declaration' do
    result = Redex::Interpreter.evaluate('const pi = 3')
    expect(result[:result]).to eq(3)
    expect(result[:env][:pi]).to eq(3)
    expect(result[:provenance][:pi]).to eq('script')
  end

  # 構文エラー
  # 観点: 不正な構文で SyntaxError が発生すること
  it 'raises SyntaxError on invalid syntax' do
    expect {
      Redex::Interpreter.evaluate('1 +')
    }.to raise_error(Redex::SyntaxError)
  end

  # 未定義変数のエラー
  # 観点: 未定義の変数参照で NameError が発生すること
  it 'raises NameError on undefined variable' do
    expect {
      Redex::Interpreter.evaluate('undefined_var')
    }.to raise_error(Redex::NameError)
  end

  # ゼロ除算のエラー
  # 観点: ゼロ除算で EvaluationError が発生すること
  it 'raises EvaluationError on division by zero' do
    expect {
      Redex::Interpreter.evaluate('10 / 0')
    }.to raise_error(Redex::EvaluationError)
  end

  # 戻り値の構造
  # 観点: 戻り値に必要なキーがすべて含まれていること
  it 'returns structured result with all required keys' do
    result = Redex::Interpreter.evaluate('1 + 1')
    
    expect(result).to have_key(:result)
    expect(result).to have_key(:env)
    expect(result).to have_key(:provenance)
    expect(result).to have_key(:errors)
    expect(result).to have_key(:diagnostics)
    expect(result).to have_key(:meta)
  end

  # メタ情報
  # 観点: meta にバージョン情報が含まれていること
  it 'includes version in meta' do
    result = Redex::Interpreter.evaluate('1')
    expect(result[:meta][:version]).to eq(Redex::VERSION)
  end
end
