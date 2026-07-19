class Saasu::Item < Saasu::Base
  allowed_methods :show, :index, :destroy, :update, :create
  filter_by %W(LastModifiedFromDate LastModifiedToDate IsActive ItemType SearchMethod PageSize)

  def build(params = {})
    Saasu::Client.request(:post, ['Item', id, 'build'].join('/'), params)
  end
end
