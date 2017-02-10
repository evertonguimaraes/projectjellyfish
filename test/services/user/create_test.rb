require 'test_helper'

class User::CreateTest < ActiveSupport::TestCase
  setup do
    @params = {
      data: {
        type: 'users',
        attributes: {
          name: 'Create Me',
          email: 'create@me.com',
          password: 'password',
          password_confirmation: 'password'
        }
      }
    }
  end

  test 'should create a new user' do
    context = nil
    result = User::Create.run(context: context, params: @params)

    assert_equal true, result.valid?
    user = User.find_by name: 'Create Me'
    assert_equal user.id, result.model.id
  end
end