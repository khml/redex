˚require 'spec_helper'
require_relative '../lib/redex/evaluator'
require_relative '../lib/redex/parser'

RSpec.describe Redex::Evaluator do
  # 算術評価（優先度）の検証
  # 観点: '*' の優先度が '+' より高く評価されること
  it 'evaluates arithmetic with precedence' do
    ast = Redex::Parser.parse('1 + 2 * 3')
    expect(Redex::Evaluator.evaluate(ast)).to eq(7)
  end

  # let 宣言の評価と環境更新
  # 観点: 右辺の式が評価され、環境にキー (シンボル) として格納されること
  it 'evaluates let and updates environment' do
    ast = Redex::Parser.parse('let x = 1 + 2')
    env = {}
    val = Redex::Evaluator.evaluate(ast, env)
    expect(val).to eq(3)
    expect(env[:x]).to eq(3)
  end

  # 識別子の解決
  # 観点: 環境から識別子の値が取得できること
  it 'resolves identifier from environment' do
    ident = Redex::Parser.parse('x')
    env = { x: 10 }
    expect(Redex::Evaluator.evaluate(ident, env)).to eq(10)
  end

  # 未定義識別子のエラー
  # 観点: 環境に存在しない識別子参照で `EvalError` が発生すること
  it 'raises on undefined identifier' do
    ident = Redex::Parser.parse('x')
    expect { Redex::Evaluator.evaluate(ident, {}) }.to raise_error(Redex::Evaluator::EvalError, /undefined variable/)
  end

  # ゼロ除算のエラー
  # 観点: 右辺が 0 の場合に `division by zero` エラーを投げること
  it 'raises on division by zero' do
    ast = Redex::Parser.parse('1 / 0')
    expect { Redex::Evaluator.evaluate(ast) }.to raise_error(Redex::Evaluator::EvalError, /division by zero/)
  end

  # 未サポート演算子のエラー（手作り AST）
  # 観点: パーサが生成しない演算子で `unknown op` エラーが発生すること
  it 'raises unknown op for unsupported operator in crafted AST' do
    node = { type: :binary, op: '^', left: { type: :number, value: 2 }, right: { type: :number, value: 3 } }
    expect { Redex::Evaluator.evaluate(node) }.to raise_error(Redex::Evaluator::EvalError, /unknown op/)
  end

  # 未知ノード種別のエラー（手作り AST）
  # 観点: 想定外のノードタイプで `unknown node type` エラーが発生すること
  it 'raises unknown node type for crafted node' do
    node = { type: :foobar }
    expect { Redex::Evaluator.evaluate(node) }.to raise_error(Redex::Evaluator::EvalError, /unknown node type/)
  end

  # const 宣言の振る舞い（現状 let と同等）
  # 観点: `const` が環境に値を格納すること（不変性は未実装）
  it 'handles const declarations like let (env update)' do
    ast = Redex::Parser.parse('const y = 4')
    env = {}
    expect(Redex::Evaluator.evaluate(ast, env)).to eq(4)
    expect(env[:y]).to eq(4)
  end
end
