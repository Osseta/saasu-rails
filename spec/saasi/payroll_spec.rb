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

  describe Saasi::Payroll::Employee do
    it 'lists employees as typed models with leave balances' do
      stub_request(:get, 'https://api.saasu.com/Payroll/Employees?FileId=777').
        to_return(status: 200, body: {
          Employees: [{ Id: 1, FirstName: 'Jack', LastName: 'Sparrow', IsActive: true,
                        LastPaid: '2026-07-31',
                        LeaveBalances: [{ PayItemId: 9, Name: 'Annual Leave', Hours: 38.5 }] }]
        }.to_json, headers: { 'Content-Type' => 'application/json' })

      employee = Saasi::Payroll::Employee.all.first
      expect(employee.first_name).to eq 'Jack'
      expect(employee.last_paid).to eq Date.new(2026, 7, 31)
      expect(employee.leave_balances.first.hours).to eq BigDecimal('38.5')
    end

    it 'unwraps the single-record Employee envelope on find' do
      stub_request(:get, 'https://api.saasu.com/Payroll/Employee/1?FileId=777').
        to_return(status: 200, body: { Employee: { Id: 1, FirstName: 'Jack' }, _links: [] }.to_json,
                  headers: { 'Content-Type' => 'application/json' })

      employee = Saasi::Payroll::Employee.find(1)
      expect(employee.first_name).to eq 'Jack'
      expect(employee.id).to eq 1
    end
  end

  describe Saasi::Payroll::Entitlement do
    it 'types the PayItem shape from the Items envelope' do
      stub_request(:get, 'https://api.saasu.com/Payroll/Entitlements?FileId=777').
        to_return(status: 200, body: { StatusMessage: 'Ok', Items: [{ Id: 9, Name: 'Annual Leave' }] }.to_json,
                  headers: { 'Content-Type' => 'application/json' })

      expect(Saasi::Payroll::Entitlement.all.first.name).to eq 'Annual Leave'
    end
  end

  describe Saasi::Payroll::PayrollEntry do
    it 'types entries including the Super wire key and nested employee' do
      wire = { 'Id' => 4, 'PayRunId' => 2, 'Status' => 1, 'Date' => '2026-07-31',
               'Employee' => { 'Id' => 1, 'FirstName' => 'Jack' },
               'Wages' => 1000.0, 'Super' => 110.0, 'IsEmpty' => false }
      entry = Saasi::Payroll::PayrollEntry.from_wire(wire)
      expect(entry.super_amount).to eq BigDecimal('110')
      expect(entry.employee.first_name).to eq 'Jack'
      expect(entry.to_wire).to eq wire
    end
  end

  describe Saasi::Payroll::LeaveRequest do
    let(:valid_attrs) do
      { leave_type_pay_item_id: 9, employee_id: 1,
        start_date: Date.new(2026, 8, 10), end_date: Date.new(2026, 8, 12), status: 'Pending' }
    end

    it 'requires the documented fields and validates the status enum' do
      request = Saasi::Payroll::LeaveRequest.new
      expect(request.valid?).to be false
      expect(request.errors.attribute_names).to include(:leave_type_pay_item_id, :employee_id, :start_date, :end_date, :status)

      expect(Saasi::Payroll::LeaveRequest.new(valid_attrs)).to be_valid
      expect(Saasi::Payroll::LeaveRequest.new(valid_attrs.merge(status: 'Maybe'))).not_to be_valid
    end

    it 'enforces the date-range rules (end >= start, max 63 days)' do
      expect(Saasi::Payroll::LeaveRequest.new(valid_attrs.merge(end_date: Date.new(2026, 8, 9)))).not_to be_valid
      expect(Saasi::Payroll::LeaveRequest.new(valid_attrs.merge(end_date: Date.new(2026, 11, 20)))).not_to be_valid
    end

    it 'requires items when the request is Approved' do
      approved = Saasi::Payroll::LeaveRequest.new(valid_attrs.merge(status: 'Approved'))
      expect(approved.valid?).to be false
      expect(approved.errors[:items]).to be_present

      approved.items = [{ date: '2026-08-10', hours: 7.6, is_paid: true }]
      expect(approved).to be_valid
      expect(approved.items.first.hours).to eq BigDecimal('7.6')
    end

    it 'round-trips, keeping the LastModifiedDateUtc concurrency token writable' do
      wire = { 'Id' => 3, 'LastModifiedDateUtc' => '2026-08-01T00:00:00Z',
               'LeaveTypePayItemId' => 9, 'EmployeeId' => 1,
               'StartDate' => '2026-08-10', 'EndDate' => '2026-08-12', 'Status' => 'Pending',
               'Items' => [{ 'LineNumber' => 1, 'Date' => '2026-08-10', 'Hours' => 7.6 }] }
      expect(Saasi::Payroll::LeaveRequest.from_wire(wire).to_wire).to eq wire
    end
  end

  describe Saasi::Payroll::Timesheet do
    it 'requires contact, start and finish' do
      timesheet = Saasi::Payroll::Timesheet.new
      expect(timesheet.valid?).to be false
      expect(timesheet.errors.attribute_names).to include(:contact_id, :start_time, :finish_time)
    end

    it 'round-trips writable fields, excluding the system-set audit fields' do
      wire = { 'Id' => 7, 'LastUpdatedId' => 'AAA=', 'ContactId' => 1,
               'StartTime' => '2026-08-06T09:00:00Z', 'FinishTime' => '2026-08-06T17:00:00Z',
               'BreakDurationInMinutes' => 30 }
      timesheet = Saasi::Payroll::Timesheet.from_wire(wire.merge('CreatedDateUtc' => '2026-08-06T00:00:00Z'))
      expect(timesheet.created_date_utc).to be_a(Time)
      expect(timesheet.to_wire).to eq wire
    end
  end

  describe Saasi::Payroll::Payslip do
    it 'delegates PDF generation' do
      stub_request(:get, 'https://api.saasu.com/Payroll/Payslip/7/generate-pdf?FileId=777').
        to_return(status: 200, body: 'PDFDATA')
      expect(Saasi::Payroll::Payslip.generate_pdf(7)).to eq 'PDFDATA'
    end
  end
end
