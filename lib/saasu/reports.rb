module Saasu
  class Reports
    def self.profit_and_loss_summary(params = {})
      Saasu::Client.request(:get, 'Reports/ProfitAndLoss/Summary', params)
    end

    def self.profit_and_loss_summary_by_account_type(params = {})
      Saasu::Client.request(:get, 'Reports/ProfitAndLoss/SummaryByAccountType', params)
    end
  end
end
