require 'spec_helper'

describe Saasi do
  it 'aliases the HTTP error classes' do
    expect(Saasi::Error).to be Saasu::Error
    expect(Saasi::NotFoundError).to be Saasu::NotFoundError
    expect(Saasi::TwoFactorRequiredError).to be Saasu::TwoFactorRequiredError
  end

  it 'delegates configuration to Saasu::Config' do
    Saasi.configure { |c| c.file_id = 4242 }
    expect(Saasu::Config.file_id).to eq 4242
  ensure
    Saasu::Config.file_id = nil
  end

  it 'exposes a Collection with metadata' do
    collection = Saasi::Collection.new([1, 2], { 'TotalRecords' => 9 })
    expect(collection).to eq [1, 2]
    expect(collection.metadata).to eq({ 'TotalRecords' => 9 })
  end

  it 'raises ValidationError carrying the model and its errors' do
    model = Struct.new(:errors).new(double(full_messages: ['Name is bad']))
    error = Saasi::ValidationError.new(model)
    expect(error.model).to be model
    expect(error.message).to include('Name is bad')
  end

  it 'aliases the raw-hash utility modules' do
    expect(Saasi::LookupData).to be Saasu::LookupData
    expect(Saasi::Reports).to be Saasu::Reports
  end
end
