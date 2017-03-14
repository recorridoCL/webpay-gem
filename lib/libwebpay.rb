require 'signer'
require 'savon'
require_relative 'verifier'
require_relative 'configuration'
require_relative 'webpay'

class Libwebpay

  @configuration
  @webpay

  def get_webpay(config)
    @webpay = Webpay.new(config) if @webpay.nil?
    @webpay
  end

  def get_configuration
    @configuration = Configuration.new if @configuration.nil?
    @configuration
  end
end
