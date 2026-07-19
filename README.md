## Ruby Software Development Kit for Saasu API
This repository is a version of the Saasu software development kit in the Ruby language, for working with the Saasu API.
For help on the API itself, you can look at the [help documentation](https://api.saasu.com/).

[![Gem Version](https://badge.fury.io/rb/saasu2.svg)](http://badge.fury.io/rb/saasu2)
[![Build Status](https://travis-ci.org/nsinenko/saasu-rails.svg?branch=master)](https://travis-ci.org/nsinenko/saasu-rails)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'saasu2'
```

And then execute:

    $ bundle

Create an initializer file with your Saasu configuration eg config/initilizers/saasu.rb
```ruby
require 'saasu'

Saasu::Config.configure do |c|
  c.username = 'username@email.com'
  c.password = 'password'
  c.file_id = 1234 # Your Saasu FileId can be found at https://secure.saasu.com/a/net/webservicessettings.aspx
end
```

You're now ready to connect your app to Saasu.

## Usage

You can access the following objects:
- Saasu::Account
- Saasu::Company
- Saasu::Contact
- Saasu::Invoice
- Saasu::InvoiceAttachment
- Saasu::Item
- Saasu::Payment
- Saasu::TaxCode
- Saasu::Search
- Saasu::User
- Saasu::FileIdentity
- Saasu::ContactAggregate
- Saasu::Activity
- Saasu::Journal
- Saasu::ItemAdjustment
- Saasu::ItemTransfer
- Saasu::Brand
- Saasu::DeletedEntity
- Saasu::Payroll::Employee
- Saasu::Payroll::Entitlement
- Saasu::Payroll::PayrollEntry
- Saasu::Payroll::LeaveRequest
- Saasu::Payroll::Timesheet
- Saasu::Payroll::Payslip
- Saasu::LookupData (countries, currencies, date_formats, industry_types, number_formats, zones)
- Saasu::Reports (profit_and_loss_summary, profit_and_loss_summary_by_account_type)

Usage examples:

```ruby
# get all contacts
contacts = Saasu::Contact.all

# find a contact by id
contact = Saasu::Contact.find(123)

# save a contact
contact.given_name = 'New Name'
contact.save

# delete a contact
contact.delete

# create a contact
new_contact = Saasu::Contact.create({ GivenName => 'User' })

# filter records. for a list of available filters for each object see https://api.saasu.com
contact = Saasu::Contact.where(GivenName: 'John')

# get attributes
contact.id
contact['Id']

# set attributes
contact.given_name = 'Nick'
contact['GivenName'] = 'John'

# get all attributes
contact.attributes

# Search. Available scopes: All, Transactions, Contacts, InventoryItems. 
query = Saasu::Search.new('Book', 'InventoryItems')
query.perform

query.contacts
query.items
query.invoices

# You can filter search results by transaction type - Sale, Purchase, Journal, Payroll
query = Saasu::Search.new('Book', scope: 'InventoryItems', transaction_type: 'Sale')

# or you can use the default scope - 'All'
query = Saasu::Search.new('Book', transaction_type: 'Purchase')

# reset user password
Saasu::User.reset_password('user@saasu.com')

# list the set of files a user has access to
Saasu::FileIdentity.all
```

Note - Saasu uses .NET naming convention for fields and filters eg. GivenName, LastModifiedDate

## Contributing

1. Fork it ( https://github.com/saasu/saasu2-ruby/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
