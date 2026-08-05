require 'spec_helper'

describe Saasu::User do
  before do
    Saasu::Config.username = "user@saasu.com"
    Saasu::Config.password = "password"
    Saasu::Config.file_id  = 777

    mock_api_requests
  end

  describe ".reset_password" do
    it 'posts anonymously, without authentication or a FileId' do
      Saasu::User.reset_password('user@saasu.com')

      expect(a_request(:post, "https://api.saasu.com/User/reset-password").
        with(body: '{"Username":"user@saasu.com"}') { |req| req.headers['Authorization'].nil? })
        .to have_been_made
      expect(a_request(:post, 'https://api.saasu.com/authorisation/token')).not_to have_been_made
    end
  end

  private
  def mock_api_requests
    stub_request(:post, "https://api.saasu.com/User/reset-password").
      with(:body => "{\"Username\":\"user@saasu.com\"}",
           headers: {'Content-Type'=>'application/json', 'X-Api-Version'=>'1.0'})
      .to_return(:status => 200, body: {}.to_json, :headers => {'Content-Type'=>'application/json'})
  end
end
