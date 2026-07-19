class Saasu::Activity < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(LastModifiedFromDate LastModifiedToDate Tags TagSelection FromDate ToDate SearchText ActivityStatus ActivityType OwnerEmail Page PageSize)
end
