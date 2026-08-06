require 'spec_helper'

describe Saasi::Payroll do
  before do
    Saasu::Config.username = 'user@saasu.com'
    Saasu::Config.password = 'password'
    Saasu::Config.file_id  = 777
    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json,
                headers: { 'Content-Type' => 'application/json' })
  end

  it 'lists employees as typed models with fields in extra' do
    stub_request(:get, 'https://api.saasu.com/Payroll/Employees?FileId=777').
      to_return(status: 200, body: { Employees: [{ Id: 1, FirstName: 'Jack' }] }.to_json,
                headers: { 'Content-Type' => 'application/json' })

    employees = Saasi::Payroll::Employee.all
    expect(employees.first.id).to eq 1
    expect(employees.first.extra['FirstName']).to eq 'Jack'
  end

  it 'round-trips employee wire hashes' do
    wire = { 'Id' => 1, 'FirstName' => 'Jack' }
    expect(Saasi::Payroll::Employee.from_wire(wire).to_wire).to eq wire
  end
end
