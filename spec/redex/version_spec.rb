require 'spec_helper'
require_relative '../../lib/redex/version'

RSpec.describe Redex do
  # 観点: ライブラリのバージョン定数が定義されていること
  # 説明: `Redex::VERSION` が nil でないことを検証する
  it 'has a version number' do
    expect(Redex::VERSION).not_to be_nil
  end
end
