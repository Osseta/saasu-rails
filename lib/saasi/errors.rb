module Saasi
  Error = Saasu::Error
  NotFoundError = Saasu::NotFoundError
  TwoFactorRequiredError = Saasu::TwoFactorRequiredError

  class ValidationError < StandardError
    attr_reader :model

    def initialize(model)
      @model = model
      super("Validation failed: #{model.errors.full_messages.join(', ')}")
    end

    def errors
      model.errors
    end
  end
end
