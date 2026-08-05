class Saasu::Contact < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(LastModifiedFromDate LastModifiedToDate GivenName FamilyName CompanyName CompanyId OrganisationName IsActive IsCustomer IsSupplier IsContractor IsPartner Tags TagSelection Email ContactId PageSize Page)

  def generate_pdf(template_id = nil)
    url = ['Contact', id, 'generate-pdf'].join('/')
    params = template_id.present? ? { TemplateId: template_id } : {}
    Saasu::Client.request(:get, url, params)
  end
end