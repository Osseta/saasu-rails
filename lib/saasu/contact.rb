class Saasu::Contact < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(LastModifiedFromDate LastModifiedToDate GivenName FamilyName CompanyName CompanyId OrganisationName IsActive IsCustomer IsSupplier IsContractor IsPartner Tags TagSelection Email ContactId PageSize Page)

  # Statement PDF — the only documented GenerateType is 'Statement', and it
  # requires a date range. (The previous template_id form matched no
  # documented parameter and could not work against the real endpoint.)
  def generate_pdf(from_date:, to_date:, generate_type: 'Statement')
    url = ['Contact', id, 'generate-pdf'].join('/')
    Saasu::Client.request(:get, url, { GenerateType: generate_type, FromDate: from_date, ToDate: to_date })
  end
end