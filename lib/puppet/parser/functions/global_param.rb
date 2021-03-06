#
# global_param.rb
#
# This function performs a lookup for a variable value in various locations
# following this order
# - Hiera backend, if present (no prefix)
# - ::coral::default::varname
# - ::varname
# - {default parameter}
#
module Puppet::Parser::Functions
  newfunction(:global_param, :type => :rvalue, :doc => <<-EOS
This function performs a lookup for a variable value in various locations following this order:
- Hiera backend, if present (no prefix)
- ::coral::default::varname
- ::varname
- {default parameter}
If no value is found in the defined sources, it returns an empty string ('')
    EOS
) do |args|
    value = nil
    Coral.backtrace do
      raise(Puppet::ParseError, "global_param(): Define at least the variable name " +
        "given (#{args.size} for 1)") if args.size < 1

      var_name      = args[0]
      default_value = ( args.size > 1 ? args[1] : '' )
      options       = ( args.size > 2 ? args[2] : {} )
    
      config = Coral::Config.new(options, {
        :scope     => self,
        :search    => 'coral::default',
        :init_fact => 'hiera_ready',
        :force     => true
      })    
      value = Coral::Config.lookup(var_name, nil, config)
    
      if value.nil?
        value = default_value
      else
        context = config.get(:context, false)
        if context && (context == :array || context == :hash)
          value = Coral::Data.merge([default_value, value], config)
        end
      end
    
      Coral::Config.set_property(var_name, value)
    end
    return value
  end
end
