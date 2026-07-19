class Saasu::Account < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(IsActive IsBankAccount AccountType IncludeBuiltIn HeaderAccountId AccountLevel PageSize Page)

  def self.bank_account_balances(params = {})
    Saasu::Client.request(:get, 'Accounts/BankAccountBalances', params)
  end
end
