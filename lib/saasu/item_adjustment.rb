class Saasu::ItemAdjustment < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(LastModifiedFromDate LastModifiedToDate Tags TagSelection FromDate ToDate Page PageSize)
end
