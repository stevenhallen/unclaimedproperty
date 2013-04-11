require 'spec_helper'

describe Property do
  let(:property) { build :property }

  before { property.populate_all }

  describe '#owner_names' do
    it { property.owner_names.should eql 'HOBBS BILL C' }
  end

  describe '#reported_owner_address' do
    it { property.reported_owner_address.should eql "2126 E ANDREWS\nFRESNO CA      -" }
  end

  describe '#property_type' do
    it { property.property_type.should eql 'Bank of America Passbooks' }
  end

  describe '#cash_report' do
    it { property.cash_report.should eql 32.94 }
  end

  describe '#reported_by' do
    it { property.reported_by.should eql 'Bank of America - Passbook Accounts' }
  end
end