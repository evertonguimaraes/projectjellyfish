class Provider < ApplicationRecord
  class CheckCredentialsJob < ApplicationJob
    def perform(provider_id)
      result = Provider::CheckCredentials.run(context: nil, params: { id: provider_id })

      if result.valid?
        # Do something
      else
        # Do something else
      end
    end
  end
end
