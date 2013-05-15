require 'json'
require 'yaml'
require 'uri'
require 'net/http'
require 'net/https'

module IronMQ
  class CoreClient
    attr_accessor :content_type
    attr_accessor :env

    def initialize(company, product, options = {}, default_options = {}, extra_options_list = [])
      @options_list = [:scheme, :host, :port, :user_agent] + extra_options_list

      metaclass = class << self
        self
      end

      @options_list.each do |option|
        metaclass.send(:define_method, option.to_s) do
          instance_variable_get('@' + option.to_s)
        end

        metaclass.send(:define_method, option.to_s + '=') do |value|
          instance_variable_set('@' + option.to_s, value)
        end
      end

      @env = options[:env] || options['env']
      @env ||= ENV[company.upcase + '_' + product.upcase + '_ENV'] || ENV[company.upcase + '_ENV']

      load_from_hash('params', options)

      load_from_config(company, product, options[:config] || options['config'])

      load_from_config(company, product, ENV[company.upcase + '_' + product.upcase + '_CONFIG'])
      load_from_config(company, product, ENV[company.upcase + '_CONFIG'])

      load_from_env(company.upcase + '_' + product.upcase)
      load_from_env(company.upcase)

      suffixes = []

      unless @env.nil?
        suffixes << "-#{@env}"
        suffixes << "_#{@env}"
      end

      suffixes << ''

      suffixes.each do |suffix|
        ['.json', '.yml'].each do |ext|
          ["#{company}-#{product}", "#{company}_#{product}", company].each do |config_base|
            load_from_config(company, product, "#{Dir.pwd}/#{config_base}#{suffix}#{ext}")
            load_from_config(company, product, "#{Dir.pwd}/.#{config_base}#{suffix}#{ext}")
            load_from_config(company, product, "#{Dir.pwd}/config/#{config_base}#{suffix}#{ext}")
            load_from_config(company, product, "#{Dir.pwd}/config/.#{config_base}#{suffix}#{ext}")
            load_from_config(company, product, "~/#{config_base}#{suffix}#{ext}")
            load_from_config(company, product, "~/.#{config_base}#{suffix}#{ext}")
          end
        end
      end

      load_from_hash('defaults', default_options)
      load_from_hash('defaults', {:user_agent => 'ironmq-openshift-cartridge'})

      @content_type = 'application/json'
    end

    def set_option(source, name, value)
      if send(name.to_s).nil? && (not value.nil?)
        send(name.to_s + '=', value)
      end
    end

    def load_from_hash(source, hash)
      return if hash.nil?

      @options_list.each do |o|
        set_option(source, o, hash[o.to_sym] || hash[o.to_s])
      end
    end

    def load_from_env(prefix)
      @options_list.each do |o|
        set_option('environment variable', o, ENV[prefix + '_' + o.to_s.upcase])
      end
    end

    def get_sub_hash(hash, subs)
      return nil if hash.nil?

      subs.each do |sub|
        return nil if hash[sub].nil?

        hash = hash[sub]
      end

      hash
    end

    def load_from_config(company, product, config_file)
      return if config_file.nil?

      if File.exists?(File.expand_path(config_file))
        config_data = '{}'

        begin
          config_data = File.read(File.expand_path(config_file))
        rescue
          return
        end

        config = nil

        if config_file.end_with?('.yml')
          config = YAML.load(config_data)
        else
          config = JSON.parse(config_data)
        end

        unless @env.nil?
          load_from_hash(config_file, get_sub_hash(config, [@env, "#{company}_#{product}"]))
          load_from_hash(config_file, get_sub_hash(config, [@env, company, product]))
          load_from_hash(config_file, get_sub_hash(config, [@env, product]))
          load_from_hash(config_file, get_sub_hash(config, [@env, company]))

          load_from_hash(config_file, get_sub_hash(config, ["#{company}_#{product}", @env]))
          load_from_hash(config_file, get_sub_hash(config, [company, product, @env]))
          load_from_hash(config_file, get_sub_hash(config, [product, @env]))
          load_from_hash(config_file, get_sub_hash(config, [company, @env]))

          load_from_hash(config_file, get_sub_hash(config, [@env]))
        end

        load_from_hash(config_file, get_sub_hash(config, ["#{company}_#{product}"]))
        load_from_hash(config_file, get_sub_hash(config, [company, product]))
        load_from_hash(config_file, get_sub_hash(config, [product]))
        load_from_hash(config_file, get_sub_hash(config, [company]))
        load_from_hash(config_file, get_sub_hash(config, []))
      end
    end

    def options(return_strings = false)
      res = {}

      @options_list.each do |option|
        res[return_strings ? option.to_s : option.to_sym] = send(option.to_s)
      end

      res
    end

    def headers
      {'User-Agent' => @user_agent}
    end

    def base_url
      "#{scheme}://#{host}:#{port}/"
    end

    def url(method)
      base_url + method
    end

    def get(method, params = {})
      uri = URI.parse(url(method))
      uri.query = URI.encode_www_form(params)

      req = Net::HTTP::Get.new(uri)

      headers.each do |name, value|
        req[name] = value
      end

      http = Net::HTTP.new(uri.hostname, uri.port)

      if scheme == 'https'
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end

      http.request(req)
    end

    def parse_response(response, parse_json = true)
      return nil if (response.code.to_i < 200 || response.code.to_i >= 300)

      body = String.new(response.body)

      return body unless parse_json

      JSON.parse(body)
    end
  end

  class Client < CoreClient
    AWS_US_EAST_HOST = 'mq-aws-us-east-1.iron.io'

    def initialize(options={})
      default_options = {
          :scheme => 'https',
          :host => IronMQ::Client::AWS_US_EAST_HOST,
          :port => 443,
          :api_version => 1
      }

      super('iron', 'mq', options, default_options, [:project_id, :token, :api_version])
    end

    def headers
      super.merge({'Authorization' => "OAuth #{@token}"})
    end

    def base_url
      @base_url = "#{super}#{@api_version}/projects/#{@project_id}/queues"
    end

    def queues(options = {})
      response = nil

      #begin
        response = parse_response(get('', options))
      #rescue
      #end

      response
    end
  end
end

client = IronMQ::Client.new

puts client.queues.inspect # FIXME - show formatted info
