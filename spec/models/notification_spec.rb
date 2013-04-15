require 'spec_helper'

describe Notification do
  
  describe '#first_name' do
    it { should have_valid(:first_name).when 'dude' }
    it { should_not have_valid(:first_name).when '', nil }
  end
  describe '#last_name' do
    it { should have_valid(:last_name).when 'duderino' }
    it { should_not have_valid(:last_name).when '', nil }
  end
  describe '#email' do
    it { should have_valid(:email).when 'dudesemail' }
    it { should_not have_valid(:email).when '', nil }
  end
end
