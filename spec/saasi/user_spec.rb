require 'spec_helper'

describe Saasi::User do
  it 'delegates reset_password to the legacy anonymous endpoint' do
    stub_request(:post, 'https://api.saasu.com/User/reset-password').
      with(body: { Username: 'user@saasu.com' }).
      to_return(status: 200, body: { StatusMessage: 'Sent' }.to_json, headers: { 'Content-Type' => 'application/json' })

    expect(Saasi::User.reset_password('user@saasu.com')).to eq 'Sent'
  end
end
