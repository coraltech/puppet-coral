#
# global_array.rb
#
# See: global_param.rb
#
module Puppet::Parser::Functions
  newfunction(:global_array, :type => :rvalue, :doc => <<-EOS
This function performs a lookup for a variable value in various locations:
See: global_params()
If no value is found in the defined sources, it returns an empty array ([])
    EOS
) do |args|
    value = nil
    Coral.backtrace do
      raise(Puppet::ParseError, "global_array(): Define at least the variable name " +
        "given (#{args.size} for 1)") if args.size < 1
    
      var_name      = args[0]
      default_value = ( args.size > 1 ? args[1] : [] ) 
      options       = ( args.size > 2 ? args[2] : {} )
    
      config = Coral::Config.new(options).set(:context, :array)
      value = function_global_param([ var_name, default_value, config.options ])
    end
    return value
  end
end
