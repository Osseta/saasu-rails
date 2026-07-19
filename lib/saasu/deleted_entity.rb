class Saasu::DeletedEntity < Saasu::Base
  allowed_methods :index
  filter_by %W(EntityType UtcDeletedFromDate UtcDeletedToDate Page PageSize)
end
