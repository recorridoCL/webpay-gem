require 'signer'
require 'savon'
require_relative 'verifier'
require_relative 'configuration'
require_relative 'webpay'

class Libwebpay

  def webpay(config)
    @webpay ||= Webpay.new(config)
  end

  def configuration
    @configuration ||= Configuration.new
  end
end
