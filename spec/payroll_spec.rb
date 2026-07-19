require 'spec_helper'

describe "Saasu::Payroll" do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    stub_request(:post, 'https://api.saasu.com/authorisation/token').
      to_return(status: 200, body: { access_token: '12345', refresh_token: '67890', expires_in: 1000 }.to_json, headers: {'Content-Type'=>'application/json'})
  end

  def stub_get(path, body)
    stub_request(:get, "https://api.saasu.com/#{path}?FileId=777").
      to_return(status: 200, body: body.to_json, headers: {'Content-Type'=>'application/json'})
  end

  it 'Employee#all hits GET Payroll/Employees' do
    stub_get('Payroll/Employees', { Employees: [{ Id: 5 }] })
    expect(Saasu::Payroll::Employee.all.first.id).to eq 5
  end

  it 'Employee#find hits GET Payroll/Employee/5' do
    stub_get('Payroll/Employee/5', { Id: 5 })
    expect(Saasu::Payroll::Employee.find(5).id).to eq 5
  end

  it 'Entitlement#all hits GET Payroll/Entitlements' do
    stub_get('Payroll/Entitlements', { Entitlements: [{ Id: 1 }] })
    expect(Saasu::Payroll::Entitlement.all.count).to eq 1
  end

  it 'PayrollEntry#all hits GET Payroll/PayrollEntries' do
    stub_get('Payroll/PayrollEntries', { PayrollEntries: [{ Id: 1 }] })
    expect(Saasu::Payroll::PayrollEntry.all.count).to eq 1
  end

  it 'LeaveRequest#find hits GET Payroll/LeaveRequest/3' do
    stub_get('Payroll/LeaveRequest/3', { Id: 3 })
    expect(Saasu::Payroll::LeaveRequest.find(3).id).to eq 3
  end

  it 'Timesheet#find hits GET Payroll/Timesheet/4' do
    stub_get('Payroll/Timesheet/4', { Id: 4 })
    expect(Saasu::Payroll::Timesheet.find(4).id).to eq 4
  end

  it 'Payslip.generate_pdf hits GET Payroll/Payslip/7/generate-pdf' do
    stub_get('Payroll/Payslip/7/generate-pdf', 'PDFDATA')
    expect(Saasu::Payroll::Payslip.generate_pdf(7)).to eq 'PDFDATA'
  end
end
