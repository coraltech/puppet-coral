
module Coral
class Config
  
  #-----------------------------------------------------------------------------
  # Global configuration

  @@properties = {}
  
  def self.properties
    return @@properties
  end
  
  def self.set_property(name, value)
    @@properties[name] = value  
  end
  
  #---
  
  def self.hiera_config
    hiera_config = Puppet.settings[:hiera_config]
    config = {}

    if File.exist?(hiera_config)
      config = Hiera::Config.load(hiera_config)
    else
      Puppet.warning "Config file #{hiera_config} not found, using Hiera defaults"
    end

    config[:logger] = 'puppet'
    config
  end
  
  #---

  def self.hiera
    @hiera ||= Hiera.new(:config => hiera_config)
  end
  
  #---

  def hiera
    self.class.hiera
  end
  
  #---
      
  def self.initialized?(options = {})
    config = Config.ensure(options)
    begin
      require 'hiera_puppet'
      
      scope       = config.get(:scope, {})
      
      sep         = config.get(:sep, '::')
      prefix      = config.get(:prefix, true)    
      prefix_text = prefix ? sep : ''
      
      init_fact   = prefix_text + config.get(:init_fact, 'hiera_ready')
      coral_fact  = prefix_text + config.get(:coral_fact, 'coral_exists') 
      
      if Puppet::Parser::Functions.function('hiera')
        if scope.respond_to?('lookupvar')
          return true if Data.true?(scope.lookupvar(init_fact)) && Data.true?(scope.lookupvar(coral_fact))
        else
          return true
        end
      end
    
    rescue Exception # Prevent abortions.
    end    
    return false
  end
  
  #---
    
  def self.lookup(name, default = nil, options = {})
    config = Config.ensure(options)
    value  = nil
    
    context     = config.get(:context, :priority)
    scope       = config.get(:scope, {})
    override    = config.get(:override, nil)
    
    base_names  = config.get(:search, nil)
    sep         = config.get(:sep, '::')
    prefix      = config.get(:prefix, true)    
    prefix_text = prefix ? sep : ''
    
    search_name = config.get(:search_name, true)
    
    #dbg(default, "lookup -> #{name}")
    
    if Config.initialized?(options)
      unless scope.respond_to?("[]")
        scope = Hiera::Scope.new(scope)
      end
      value = hiera.lookup(name, default, scope, override, context)
      #dbg(value, "hiera -> #{name}")
    end 
    
    if Data.undef?(value) && scope.respond_to?('lookupvar')
      log_level = Puppet::Util::Log.level
      Puppet::Util::Log.level = :err # Don't want failed parameter lookup warnings here.
      
      if base_names
        if base_names.is_a?(String)
          base_names = [ base_names ]
        end
        base_names.each do |item|
          value = scope.lookupvar("#{prefix_text}#{item}#{sep}#{name}")
          #dbg(value, "#{prefix_text}#{item}#{sep}#{name}")
          break unless Data.undef?(value)  
        end
      end
      if Data.undef?(value) && search_name
        value = scope.lookupvar("#{prefix_text}#{name}")
        #dbg(value, "#{prefix_text}#{name}")
      end
      Puppet::Util::Log.level = log_level
    end    
    value = default if Data.undef?(value)
    value = Data.value(value)
    
    set_property(name, value)
    
    #dbg(value, "result -> #{name}")    
    return value  
  end
  
  #-----------------------------------------------------------------------------
  # Instance generator
  
  def self.ensure(config)
    case config
    when Coral::Config
      return config
    when Hash
      return Config.new(config) 
    end
    return Config.new
  end
  
  #-----------------------------------------------------------------------------
  # Configuration instance
    
  def initialize(data = {}, defaults = {}, force = true)
    @force = force
    
    if defaults.is_a?(Hash) && ! defaults.empty?
      symbolized = {}
      defaults.each do |key, value|
        symbolized[key.to_sym] = value
      end
      defaults = symbolized
    end
    
    case data
    when Coral::Config
      @options = Data.merge([ defaults, data.options ], force)
    when Hash
      @options = {}
      if data.is_a?(Hash)
        symbolized = {}
        data.each do |key, value|
          symbolized[key.to_sym] = value
        end
        @options = Data.merge([ defaults, symbolized ], force)
      end  
    end
  end
  
  #---
  
  def import(data, options = {})
    config = Config.new(options, { :force => @force }).set(:context, :hash)
    
    case data
    when Hash
      symbolized = {}
      data.each do |key, value|
        symbolized[key.to_sym] = value
      end
      @options = Data.merge([ @options, symbolized ], config)
    
    when String      
      data   = Data.lookup(data, {}, config)
      Data.merge([ @options, data ], config)
     
    when Array
      data.each do |item|
        import(item, config)
      end
    end
    
    return self
  end
  
  #---
  
  def set(name, value)
    @options[name.to_sym] = value
    return self
  end
  
  def []=(name, value)
    set(name, value)
  end
  
  #---
    
  def get(name, default = nil)
    name = name.to_sym
    return @options[name] if @options.has_key?(name)
    return default
  end
  
  def [](name, default = nil)
    get(name, default)
  end
  
  #---
  
  def options
    return @options
  end
end
end