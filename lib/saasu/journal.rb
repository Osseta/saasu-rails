class Saasu::Journal < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(LastModifiedFromDate LastModifiedToDate Tags TagSelection FromDate ToDate JournalContactId Page PageSize)
end
