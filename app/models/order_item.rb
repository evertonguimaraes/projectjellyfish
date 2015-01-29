class OrderItem < ActiveRecord::Base
  acts_as_paranoid

  before_create :load_order_item_params

  after_commit :provision, on: :create

  belongs_to :order
  belongs_to :product
  belongs_to :cloud
  belongs_to :project

  enum provision_status: { ok: 0, warning: 1, critical: 2, unknown: 3, pending: 4 }

  validates :product, presence: true
  validate :validate_product_id

  private

  def validate_product_id
    errors.add(:product, 'Product does not exist.') unless Product.exists?(product_id)
  end

  def load_order_item_params
    self.hourly_price = product.hourly_price
    self.monthly_price = product.monthly_price
    self.setup_price = product.setup_price
  end

  def provision
    # Calling save inside an after_commit on: :create triggers a :create callback again.
    # Passed the object to the provision_order_item and called the save there.
    # https://github.com/rails/rails/issues/14493#issuecomment-39859373
    order_item = self

    order_item.delay(queue: 'provision_request').provision_order_item(order_item)
  end

  def provision_order_item(order_item)
    #details = product_details(order_item)

    message =
    {
      action: 'order',
      resource: {
        href: "#{ENV['MANAGEIQ_HOST']}/api/service_templates/#{order_item.product.service_type_id}",
        id: order_item.id,
        uuid: order_item.uuid.to_s,
        product_details: {}
      }
    }

    order_item.provision_status = :unknown
    order_item.payload_to_miq = message.to_json
    order_item.save

    # TODO: Retrieving these values from the database could be done way better
    @miq_settings = SettingField.where(setting_id: 2).order(load_order: :asc).as_json

    # TODO: verify_ssl needs to be changed, this is the only way I could get it to work in development.
    resource = RestClient::Resource.new(
        @miq_settings[0]['value'],
        user: @miq_settings[1]['value'],
        password: @miq_settings[2]['value'],
        verify_ssl: OpenSSL::SSL::VERIFY_NONE
    )

    begin
      @response = resource["api/service_catalogs/#{order_item.product.service_catalog_id}/service_templates"].post message.to_json, content_type: 'application/json'
    rescue => e
      @response = e.response
    end

    data = ActiveSupport::JSON.decode(@response)
    order_item.payload_reply_from_miq = data.to_json

    case @response.code
    when 200..299
      order_item.provision_status = :pending
      order_item.miq_id = data['results'][0]['id']
    when 400..499
      order_item.provision_status = :critical
    else
      order_item.provision_status = :warning
    end

    order_item.save
    order_item.to_json
  end

  def product_details(order_item)
    product_details_hash = {}

    answers = order_item.product.answers
    order_item.product.product_type.questions.each do |question|
      answer = answers.select { |row| row.product_type_id == question.product_type_id }.first
      product_details_hash[question.manageiq_key] = answer.nil ? question.default : answer.answer
    end

    product_details_hash
  end
end
