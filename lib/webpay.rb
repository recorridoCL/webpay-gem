require_relative 'webpay_mall_normal'
require_relative 'webpay_normal'
require_relative 'webpay_nullify'
require_relative 'webpay_capture'
require_relative 'webpay_one_click'
require_relative 'webpay_complete'

class Webpay

  ENV_ENDPOINTS = {
    'PRODUCCION' => 'https://webpay3g.transbank.cl',
    'CERTIFICACION' => 'https://webpay3gint.transbank.cl',
    'INTEGRACION' => 'https://webpay3gint.transbank.cl'
  }.freeze


  def initialize(params)
    @configuration = params
  end

  def get_normal_transaction
    @webpay_normal ||= WebpayNormal.new(@configuration)
  end

  def get_mall_normal_transaction
    @webpay_mall_normal ||= WebpayMallNormal.new(@configuration)
  end

  def get_nullify_transaction
    @webpay_nullify ||= WebpayNullify.new(@configuration)
  end

  def get_capture_transaction
    @webpay_capture ||= WebpayCapture.new(@configuration)
  end

  def get_one_click_transaction
    @webpay_one_click ||= WebpayOneClick.new(@configuration)
  end

  def get_complete_transaction
    @webpay_complete_transaction ||= WebpayComplete.new(@configuration)
  end
end



