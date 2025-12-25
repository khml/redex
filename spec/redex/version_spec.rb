require 'spec_helper'
require_relative '../../lib/redex/version'

RSpec.describe Redex do
  it 'has a version number' do
    expect(Redex::VERSION).not_to be_nil
  end
end
