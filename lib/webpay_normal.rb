require 'signer'
require 'savon'
require_relative "verifier"

class WebpayNormal

  def initialize(configuration)
    @environment = configuration.environment
    @proxy = configuration.proxy
    @wsdl_path = File.join(File.dirname(__FILE__), "wsdl/normal/#{@environment.downcase}.xml")
    @commerce_code = configuration.commerce_code
    @private_key = OpenSSL::PKey::RSA.new(configuration.private_key)
    @public_cert = OpenSSL::X509::Certificate.new(configuration.public_cert)
    @webpay_cert = OpenSSL::X509::Certificate.new(configuration.webpay_cert)
    base_config = {
      wsdl: @wsdl_path,
      log_level: :debug,
      open_timeout: 20,
      read_timeout: 20,
      ssl_verify_mode: :none,
      log: true
    }
    base_config[:endpoint] = "#{@proxy}/WSWebpayTransaction/cxf/WSWebpayService" if @proxy
    @client = Savon.client(base_config)
  end


  #######################################################
  def init_transaction(amount, buyOrder, sessionId, urlReturn, urlFinal)


    initInput ={
        "wsInitTransactionInput" => {
            "wSTransactionType" => "TR_NORMAL_WS",
            "buyOrder" => buyOrder,
            "sessionId" => sessionId,
            "returnURL" => urlReturn,
            "finalURL" => urlFinal,
            "transactionDetails" => {
                "amount" => amount,
                "commerceCode" => @commerce_code,
                "buyOrder" => buyOrder
            }
        }
    }

    req = @client.build_request(:init_transaction, message: initInput)

    #Firmar documento
    document = sign_xml(req)
    puts "Documento firmado para #{buyOrder} en InitTransaction: #{document.to_s.gsub("\n", '')}"

    begin
      response = @client.call(:init_transaction) do
        xml document.to_xml(:save_with => 0)
      end
    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay para #{buyOrder} en InitTransaction: #{e.message}"
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay para #{buyOrder} en InitTransaction: #{e.message}"
      }
      return response_array
    end

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      puts "El Certificado de respuesta es Invalido para #{buyOrder} en InitTransaction"
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido para #{buyOrder} en InitTransaction"
    end


    token=''
    response_document = Nokogiri::HTML(response.to_s)
    response_document.xpath("//token").each do |token_value|
      token = token_value.text
    end
    url=''
    response_document.xpath("//url").each do |url_value|
      url = url_value.text
    end

    puts "token para #{buyOrder} es #{token}"
    puts "url para #{buyOrder} es #{url}"

    response_array ={
        "token" => token.to_s,
        "url" => url.to_s,
        "error_desc" => "TRX_OK"
    }

    return response_array
  end


  ##############################################
  def get_transaction_result(token)

    getResultInput ={
        "tokenInput" => token
    }

    #Preparacion firma
    req = @client.build_request(:get_transaction_result, message: getResultInput)
    #firmar la peticion
    document = sign_xml(req)

    #Se realiza el getResult
    begin
      puts "Iniciando GetResult para #{token}"
      response = @client.call(:get_transaction_result) do
        xml document.to_xml(:save_with => 0)
      end

    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay para #{token} en GetResult: #{e.message}"
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay para #{token} en GetResult: #{e.message}"
      }
      return response_array
    end

    #Se revisa que respuesta no sea nula.
    if response
      puts "Respuesta GetResult para #{token}: #{response.to_s}"
    else
      puts "Webservice Webpay responde con null para #{token}"
      response_array ={
          "error_desc" => 'Webservice Webpay responde con null'
      }
      return response_array
    end

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      puts "El Certificado de respuesta es Invalido para #{token} en GetResult"
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido para #{token} en GetResult"
    end


    response_document = Nokogiri::HTML(response.to_s)

    {
        "accounting_date" => response_document.xpath("//accountingdate").text.to_s,
        "buy_order" => response_document.at_xpath("//buyorder").text.to_s,
        "card_number" => response_document.xpath("//cardnumber").text.to_s,
        "amount" => response_document.xpath("//amount").text.to_s,
        "commerce_code" => response_document.xpath("//commercecode").text.to_s,
        "authorization_code" => response_document.xpath("//authorizationcode").text.to_s,
        "payment_type_code" => response_document.xpath("//paymenttypecode").text.to_s,
        "response_code" => response_document.xpath("//responsecode").text.to_s,
        "transaction_date" => response_document.xpath("//transactiondate").text.to_s,
        "url_redirection" => response_document.xpath("//urlredirection").text.to_s,
        "vci" => response_document.xpath("//vci").text.to_s,
        "shares_number" => response_document.xpath("//sharesnumber").text.to_s,
        "error_desc" => 'TRX_OK'
    }
  end


  ################################
  def acknowledge_transaction(token)
    acknowledgeInput ={
        "tokenInput" => token
    }

    #Preparacion firma
    req = @client.build_request(:acknowledge_transaction, message: acknowledgeInput)

    #Se firma el body de la peticion
    document = sign_xml(req)

    #Se realiza el acknowledge_transaction
    begin
      puts "Iniciando acknowledge_transaction para #{token} ..."
      response = @client.call(:acknowledge_transaction, message: acknowledgeInput) do
        xml document.to_xml(:save_with => 0)
      end

    rescue Exception, RuntimeError => e
      puts "Ocurrio un error en la llamada a Webpay para #{token} en acknowledge_transaction:  #{e.message}"
      response_array ={
          "error_desc" => "Ocurrio un error en la llamada a Webpay para #{token} en acknowledge_transaction:  #{e.message}"
      }
      return response_array
    end

    #Se revisa que respuesta no sea nula.
    if response
      puts "Respuesta acknowledge_transaction para #{token} : #{response.to_s}"
    else
      puts "Webservice Webpay responde con null para #{token} en acknowledge_transaction"
      response_array ={
          "error_desc" => 'Webservice Webpay responde con null'
      }
      return response_array
    end

    #Verificacion de certificado respuesta
    tbk_cert = OpenSSL::X509::Certificate.new(@webpay_cert)

    if !Verifier.verify(response, tbk_cert)
      puts "El Certificado de respuesta es Invalido para #{token} en acknowledge_transaction"
      response_array ={
          "error_desc" => 'El Certificado de respuesta es Invalido'
      }
      return response_array
    else
      puts "El Certificado de respuesta es Valido para #{token} en acknowledge_transaction"
    end

    response_array ={
        "error_desc" => 'TRX_OK'
    }
    return response_array

  end


  def sign_xml (input_xml)

    document = Nokogiri::XML(input_xml.body)
    envelope = document.at_xpath("//env:Envelope")
    envelope.prepend_child("<env:Header><wsse:Security xmlns:wsse='http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' wsse:mustUnderstand='1'/></env:Header>")
    xml = document.to_s

    signer = Signer.new(xml)

    signer.cert = OpenSSL::X509::Certificate.new(@public_cert)
    signer.private_key = OpenSSL::PKey::RSA.new(@private_key)

    signer.document.xpath("//soapenv:Body", {"soapenv" => "http://schemas.xmlsoap.org/soap/envelope/"}).each do |node|
      signer.digest!(node)
    end

    signer.sign!(:issuer_serial => true)
    signed_xml = signer.to_xml

    document = Nokogiri::XML(signed_xml)
    x509data = document.at_xpath("//*[local-name()='X509Data']")
    new_data = x509data.clone()
    new_data.set_attribute("xmlns:ds", "http://www.w3.org/2000/09/xmldsig#")

    n = Nokogiri::XML::Node.new('wsse:SecurityTokenReference', document)
    n.add_child(new_data)
    x509data.add_next_sibling(n)

    return document
  end

end