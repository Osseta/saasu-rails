module Saasu
  module Payroll
    class Employee < Saasu::Base
      allowed_methods :show, :index
      # IsActive/IncludeLeaveBalances/LeaveBalanceAsAtDate are the documented filters;
      # Page/PageSize kept for backwards compatibility (undocumented for this endpoint)
      filter_by %W(IsActive IncludeLeaveBalances LeaveBalanceAsAtDate Page PageSize)

      def self.resource_url(id = nil)
        ['Payroll/Employee', id].compact.join('/')
      end
    end

    class Entitlement < Saasu::Base
      allowed_methods :index
      filter_by %W(Page PageSize)
      collection_key 'Items' # PayItemListResponse keys the collection as Items, not Entitlements

      def self.resource_url(id = nil)
        ['Payroll/Entitlement', id].compact.join('/')
      end
    end

    class PayrollEntry < Saasu::Base
      allowed_methods :index
      filter_by %W(FromDate ToDate EmployeeId Page PageSize)

      def self.resource_url(id = nil)
        ['Payroll/PayrollEntry', id].compact.join('/')
      end
    end

    class LeaveRequest < Saasu::Base
      allowed_methods :show, :create, :update, :destroy

      def self.resource_url(id = nil)
        ['Payroll/LeaveRequest', id].compact.join('/')
      end
    end

    class Timesheet < Saasu::Base
      allowed_methods :show, :create, :update, :destroy

      def self.resource_url(id = nil)
        ['Payroll/Timesheet', id].compact.join('/')
      end
    end

    class Payslip < Saasu::Base
      # id is a PayrollEntry/Transaction id, not an employee id.
      # TemplateId is not a documented parameter for payslips; it is only sent
      # when a caller explicitly passes it (kept for backwards compatibility).
      def self.generate_pdf(id, template_id = nil)
        url = ['Payroll/Payslip', id, 'generate-pdf'].join('/')
        params = template_id.present? ? { TemplateId: template_id } : {}
        Saasu::Client.request(:get, url, params)
      end

      def generate_pdf(template_id = nil)
        self.class.generate_pdf(id, template_id)
      end
    end
  end
end
