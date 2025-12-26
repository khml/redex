require 'spec_helper'
require_relative '../lib/redex/evaluator'
require_relative '../lib/redex/parser'

RSpec.describe Redex::Evaluator do
  # 算術評価（優先度）の検証
  # 観点: '*' の優先度が '+' より高く評価されること
  it 'evaluates arithmetic with precedence' do
    ast = Redex::Parser.parse('1 + 2 * 3')
    result = Redex::Evaluator.evaluate(ast)
    expect(result[:result]).to eq(7)
  end

  # let 宣言の評価と環境更新
  # 観点: 右辺の式が評価され、環境にキー (シンボル) として格納されること
  it 'evaluates let and updates environment' do
    ast = Redex::Parser.parse('let x = 1 + 2')
    result = Redex::Evaluator.evaluate(ast)
    expect(result[:result]).to eq(3)
    expect(result[:env][:x]).to eq(3)
    expect(result[:provenance][:x]).to eq('script')
  end

  # 識別子の解決
  # 観点: 環境から識別子の値が取得できること
  it 'resolves identifier from environment' do
    ident = Redex::Parser.parse('x')
    result = Redex::Evaluator.evaluate(ident, { x: 10 })
    expect(result[:result]).to eq(10)
  end

  # 未定義識別子のエラー
  # 観点: 環境に存在しない識別子参照で `NameError` が発生すること
  it 'raises on undefined identifier' do
    ident = Redex::Parser.parse('x')
    expect { Redex::Evaluator.evaluate(ident, {}) }.to raise_error(Redex::NameError, /undefined variable/)
  end

  # ゼロ除算のエラー
  # 観点: 右辺が 0 の場合に `division by zero` エラーを投げること
  it 'raises on division by zero' do
    ast = Redex::Parser.parse('1 / 0')
    expect { Redex::Evaluator.evaluate(ast) }.to raise_error(Redex::EvaluationError, /division by zero/)
  end

  # 未サポート演算子のエラー（手作り AST）
  # 観点: パーサが生成しない演算子で `unknown op` エラーが発生すること
  it 'raises unknown op for unsupported operator in crafted AST' do
    node = { type: :binary, op: '^', left: { type: :number, value: 2 }, right: { type: :number, value: 3 } }
    expect { Redex::Evaluator.evaluate(node) }.to raise_error(Redex::EvaluationError, /unknown op/)
  end

  # 未知ノード種別のエラー（手作り AST）
  # 観点: 想定外のノードタイプで `unknown node type` エラーが発生すること
  it 'raises unknown node type for crafted node' do
    node = { type: :foobar }
    expect { Redex::Evaluator.evaluate(node) }.to raise_error(Redex::EvaluationError, /unknown node type/)
  end

  # const 宣言の振る舞い（環境への格納と provenance）
  # 観点: `const` が環境に値を格納し、provenance に記録されること
  it 'handles const declarations with env update and provenance' do
    ast = Redex::Parser.parse('const y = 4')
    result = Redex::Evaluator.evaluate(ast)
    expect(result[:result]).to eq(4)
    expect(result[:env][:y]).to eq(4)
    expect(result[:provenance][:y]).to eq('script')
  end

  # const 再代入のエラー
  # 観点: const で定義された名前への再代入で `EvaluationError` が発生すること
  it 'raises on reassignment to const' do
    evaluator = Redex::Evaluator.new({})
    ast1 = Redex::Parser.parse('const z = 10')
    evaluator.eval(ast1)
    
    ast2 = Redex::Parser.parse('let z = 20')
    expect { evaluator.eval(ast2) }.to raise_error(Redex::EvaluationError, /cannot reassign to const/)
  end

  # context の数値検証
  # 観点: context に非数値が含まれている場合、初期化時に EvaluationError が発生すること
  it 'raises on non-numeric context value' do
    expect {
      Redex::Evaluator.new({}, context: { 'x' => 'not a number' })
    }.to raise_error(Redex::EvaluationError, /context value.*must be numeric/)
  end

  # context からの識別子解決
  # 観点: context で提供された値が解決され、provenance に記録されること
  it 'resolves identifier from context' do
    ident = Redex::Parser.parse('x')
    result = Redex::Evaluator.evaluate(ident, {}, context: { 'x' => 5 })
    expect(result[:result]).to eq(5)
    expect(result[:provenance][:x]).to eq('context')
  end

  # スクリプト定義が context をシャドウ
  # 観点: スクリプト内で定義された名前が context の同名値より優先されること
  it 'script definition shadows context' do
    ast = Redex::Parser.parse('let x = 100')
    result = Redex::Evaluator.evaluate(ast, {}, context: { 'x' => 5 })
    expect(result[:result]).to eq(100)
    expect(result[:env][:x]).to eq(100)
    expect(result[:provenance][:x]).to eq('script')
  end

  # ruby_resolver での識別子解決
  # 観点: ruby_resolver が未解決の識別子を解決できること
  it 'resolves identifier via ruby_resolver' do
    resolver = ->(name, _ctx) do
      case name
      when 'y' then 42
      else nil
      end
    end
    
    ident = Redex::Parser.parse('y')
    result = Redex::Evaluator.evaluate(ident, {}, ruby_resolver: resolver)
    expect(result[:result]).to eq(42)
    expect(result[:provenance][:y]).to eq('ruby_resolver')
  end

  # ruby_resolver が nil を返した場合のエラー
  # 観点: ruby_resolver が nil を返すと NameError が発生すること
  it 'raises NameError when ruby_resolver returns nil' do
    resolver = ->(_name, _ctx) { nil }
    
    ident = Redex::Parser.parse('unknown')
    expect {
      Redex::Evaluator.evaluate(ident, {}, ruby_resolver: resolver)
    }.to raise_error(Redex::NameError, /undefined variable/)
  end

  # ruby_resolver が非数値を返した場合のエラー
  # 観点: ruby_resolver が非数値を返すと EvaluationError が発生すること
  it 'raises EvaluationError when ruby_resolver returns non-numeric' do
    resolver = ->(_name, _ctx) { 'not a number' }
    
    ident = Redex::Parser.parse('y')
    expect {
      Redex::Evaluator.evaluate(ident, {}, ruby_resolver: resolver)
    }.to raise_error(Redex::EvaluationError, /must return numeric value/)
  end
end
