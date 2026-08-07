module Saasi
  # Field contracts sourced from the live API docs (api.saasu.com/Help/Api/*),
  # which document payroll fully even though the official .NET SDK never did.
  module Payroll
    class LeaveBalance < Saasi::Base
      attribute :pay_item_id, :integer
      attribute :name,        :string
      attribute :hours,       :decimal
    end

    class Employee < Saasi::Base
      wraps Saasu::Payroll::Employee

      attribute :id,                       :integer
      attribute :first_name,               :string
      attribute :last_name,                :string
      attribute :display_name,             :string
      attribute :is_active,                :boolean
      attribute :employment_type_id,       :integer
      attribute :employment_type,          :string
      attribute :pay_frequency_id,         :integer
      attribute :pay_frequency,            :string
      attribute :assigned_to_pay_group_id, :integer
      attribute :pay_group_name,           :string
      attribute :last_paid,                :date

      has_many :leave_balances, LeaveBalance # populated only with IncludeLeaveBalances=true

      # single GET returns an envelope: { "Employee": { ... }, "_links": [] }
      def self.find(id)
        record = wraps.find(id)
        return unless record

        hash = record.attributes
        from_wire(hash['Employee'] || hash)
      end
    end

    class Entitlement < Saasi::Base
      wraps Saasu::Payroll::Entitlement

      attribute :id,   :integer
      attribute :name, :string
    end

    class PayrollEntry < Saasi::Base
      wraps Saasu::Payroll::PayrollEntry

      attribute :id,           :integer
      attribute :pay_run_id,   :integer
      attribute :status,       :integer # numeric enum; values not documented by the API
      attribute :date,         :date
      attribute :wages,        :decimal
      attribute :deductions,   :decimal
      attribute :taxes,        :decimal
      attribute :net_pay,      :decimal
      attribute :super_amount, :decimal, wire_key: 'Super' # `super` is a Ruby keyword
      attribute :is_empty,     :boolean

      has_one :employee, Employee
    end

    class LeaveRequest < Saasi::Base
      class Item < Saasi::Base
        attribute :line_number,             :integer
        attribute :date,                    :date
        attribute :hours,                   :decimal
        attribute :is_paid,                 :boolean
        attribute :processed_in_pay_run_id, :integer
      end

      wraps Saasu::Payroll::LeaveRequest

      MAX_DURATION_DAYS = 63 # "maximum duration ... is 3 months (63 days)"

      attribute :id,                      :integer
      attribute :created_date_utc,        :datetime
      # unlike every other resource, LeaveRequest's concurrency token is
      # LastModifiedDateUtc (required on PUT), not LastUpdatedId
      attribute :last_modified_date_utc,  :datetime
      attribute :leave_type_pay_item_id,  :integer # pay item ids come from Payroll/Entitlements
      attribute :employee_id,             :integer
      attribute :start_date,              :date
      attribute :end_date,                :date
      attribute :total_hours,             :decimal
      attribute :status,                  :string
      attribute :notes,                   :string

      has_many :items, Item

      read_only :created_date_utc, :total_hours

      validates :leave_type_pay_item_id, :employee_id, :start_date, :end_date, :status, presence: true
      validates :status, inclusion: { in: Saasu::Constants::LEAVE_REQUEST_STATUSES }, allow_nil: true
      validate :date_range_is_valid
      validate :approved_requests_have_items

      def date_range_is_valid
        return unless start_date && end_date

        errors.add(:end_date, 'must be on or after start date') if end_date < start_date
        errors.add(:end_date, "must be within #{MAX_DURATION_DAYS} days of start date") if (end_date - start_date).to_i > MAX_DURATION_DAYS
      end

      def approved_requests_have_items
        errors.add(:items, 'must be provided for approved leave requests') if status == 'Approved' && items.empty?
      end
    end

    class Timesheet < Saasi::Base
      wraps Saasu::Payroll::Timesheet

      attribute :id,                        :integer
      attribute :last_updated_id,           :string # concurrency token, required for update
      attribute :last_modified_date_utc,    :datetime
      attribute :created_date_utc,          :datetime
      attribute :last_modified_by_user_id,  :integer
      attribute :contact_id,                :integer # the employee's CONTACT id (see GET Payroll/Employees)
      attribute :start_time,                :datetime
      attribute :finish_time,               :datetime
      attribute :break_duration_in_minutes, :integer
      attribute :notes,                     :string

      read_only :created_date_utc, :last_modified_date_utc, :last_modified_by_user_id

      validates :contact_id, :start_time, :finish_time, presence: true
    end

    class Payslip
      # id is a PayrollEntry/Transaction id, not an employee id; returns raw PDF bytes
      def self.generate_pdf(id, template_id = nil)
        Saasu::Payroll::Payslip.generate_pdf(id, template_id)
      end
    end
  end
end
