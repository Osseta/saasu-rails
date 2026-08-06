module Saasi
  module Payroll
    class Employee < Saasi::Base
      wraps Saasu::Payroll::Employee
      attribute :id, :integer
    end

    class Entitlement < Saasi::Base
      wraps Saasu::Payroll::Entitlement
      attribute :id, :integer
    end

    class PayrollEntry < Saasi::Base
      wraps Saasu::Payroll::PayrollEntry
      attribute :id, :integer
    end

    class LeaveRequest < Saasi::Base
      wraps Saasu::Payroll::LeaveRequest
      attribute :id, :integer
    end

    class Timesheet < Saasi::Base
      wraps Saasu::Payroll::Timesheet
      attribute :id, :integer
    end

    class Payslip
      # PDF generation only; returns the raw PDF string
      def self.generate_pdf(id, template_id = nil)
        Saasu::Payroll::Payslip.generate_pdf(id, template_id)
      end
    end
  end
end
