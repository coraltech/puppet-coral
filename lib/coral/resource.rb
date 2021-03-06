
module Coral
module Resource
  
  @@resource_groups = {}
  
  def self.groups
    return @@resource_groups
  end
  
  def self.clear_groups
    @@resource_groups = {}
  end
  
  def self.add_members(group_name, resource_names)
    @@resource_groups[group_name] = [] unless @@resource_groups[group_name].is_a?(Array)
    
    unless resource_names.is_a?(Array)
      resource_names = [ resource_names ]
    end
    
    resource_names.each do |name|
      unless @@resource_groups[group_name].include?(name)
        @@resource_groups[group_name] << name
      end
    end
  end
  
  #---
  
  def self.normalize(type_name, resources, options)
    clear_groups
    
    config    = Config.ensure(options)
    resources = Data.value(resources)
    
    #prefix = config.get(:resource_prefix, '')
    #prefix = "#{prefix}_" unless prefix.empty?
    
    #dbg(resources, 'normalize -> init')
    
    unless Data.undef?(resources) || resources.empty?
      resources.keys.each do |name|
        #dbg(name, 'normalize -> name')
        if ! resources[name] || resources[name].empty? || ! resources[name].is_a?(Hash)        
          resources.delete(name)
        else
          normalize = true
          
          namevar = namevar(type_name, name)
          if resources[name].has_key?(namevar)
            value = resources[name][namevar]
            if Data.undef?(value) || value.empty?
              #dbg(value, "delete #{name}")
              resources.delete(name)
              normalize = false
              
            elsif value.is_a?(Array)
              value.each do |item|
                item_name = "#{name}_#{item}".gsub(/\-/, '_')
                
                new_resource = resources[name].clone
                new_resource[namevar] = item
                
                resources[item_name] = normalize_keys(new_resource)
                add_members(name, item_name)
              end
              resources.delete(name)
              normalize = false
            end  
          end
          
          #dbg(resources, 'normalize -> resources')
          
          if normalize
            resources[name] = normalize_keys(resources[name])
          end
        end
      end
    end
    return resources
  end
  
  #---
  
  def self.translate(type_name, resources, options = {})
    config    = Config.ensure(options)
    resources = Data.value(resources)
    results   = {}
        
    #dbg(resources, 'resources -> translate')
    
    prefix = config.get(:resource_prefix, '')
    
    name_map = {}
    resources.keys.each do |name|
      name_map[name] = true
    end
    config[:resource_names] = name_map
    
    resources.each do |name, data|
      #dbg(name, 'name')
      #dbg(data, 'data')
      
      resource = resources[name]
      resource['before']    = translate_resource_refs(type_name, data['before'], config) if data.has_key?('before')
      resource['notify']    = translate_resource_refs(type_name, data['notify'], config) if data.has_key?('notify')
      resource['require']   = translate_resource_refs(type_name, data['require'], config) if data.has_key?('require')       
      resource['subscribe'] = translate_resource_refs(type_name, data['subscribe'], config) if data.has_key?('subscribe')
      
      unless prefix.empty?
        name = "#{prefix}_#{name}"
      end
      results[name] = resource
    end
    return results
  end
  
  #---
  
  def self.translate_resource_refs(type_name, resource_refs, options = {})
    return :undef if Data.undef?(resource_refs)
    
    config         = Config.ensure(options)
    resource_names = config.get(:resource_names, {})
    title_prefix   = config.get(:title_prefix, '')
    
    title_pattern  = config.get(:title_pattern, '^\s*([^\[\]]+)\s*$')
    title_group    = config.get(:title_var_group, 1)
    title_flags    = config.get(:title_flags, '')
    title_regexp   = Regexp.new(title_pattern, title_flags.split(''))
    
    allow_single   = config.get(:allow_single_return, true)    
    
    type_name      = type_name.sub(/^\@?\@/, '')
    values         = []
        
    case resource_refs
    when String
      if resource_refs.empty?
        return :undef 
      else
        resource_refs = resource_refs.split(/\s*,\s*/)
      end
        
    when Puppet::Resource
      resource_refs = [ resource_refs ]  
    end
    
    resource_refs.collect! do |value|
      if value.is_a?(Puppet::Resource) || ! value.match(title_regexp)
        value
          
      elsif resource_names.has_key?(value)
        if ! title_prefix.empty?
          "#{title_prefix}_#{value}"
        else
          value
        end
        
      elsif groups.has_key?(value) && ! groups[value].empty?
        results = []
        groups[value].each do |resource_name|
          unless title_prefix.empty?
            resource_name = "#{title_prefix}_#{resource_name}"
          end
          results << resource_name        
        end
        results
        
      else
        nil
      end           
    end
    
    resource_refs.flatten.each do |ref|
      #dbg(ref, 'reference -> init')
      unless ref.nil?        
        unless ref.is_a?(Puppet::Resource)
          ref = ref.match(title_regexp) ? Puppet::Resource.new(type_name, ref) : Puppet::Resource.new(ref)
        end
        #dbg(ref, 'reference -> final')       
        values << ref unless ref.nil?
      end
    end
    return values[0] if allow_single && values.length == 1
    return values
  end
  
  #---
  
  def self.type_name(value) # Basically borrowed from Puppet (damn private methods!)
    return :main if value == :main
    return "Class" if value == "" or value.nil? or value.to_s.downcase == "component"
    return value.to_s.split("::").collect { |s| s.capitalize }.join("::")
  end
  
  #---
  
  def self.namevar(type_name, resource_name) # Basically borrowed from Puppet (damn private methods!)
    resource = Puppet::Resource.new(type_name.sub(/^\@?\@/, ''), resource_name)
    
    if resource.builtin_type? and type = resource.resource_type and type.key_attributes.length == 1
      return type.key_attributes.first.to_s
    else
      return 'name'
    end
  end
    
  #---
  
  def self.normalize_keys(hash)
    result = {}
    hash.each do |key, value|
      result[key.to_s] = value
    end
    return result
  end
end
end