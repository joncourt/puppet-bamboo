require 'spec_helper'

describe 'bamboo' do
  it { should contain_service('bamboo').with_ensure('running') }
end

