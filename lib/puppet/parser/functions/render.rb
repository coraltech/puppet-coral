#
# render.rb
#
# Returns the string-ified form of a given value or set of values.
#
module Puppet::Parser::Functions
  newfunction(:render, :type => :rvalue, :doc => <<-EOS
This function returns the string-ified form of a given value.
    EOS
) do |args|
    value = nil
    Coral.backtrace do
      raise(Puppet::ParseError, "render(): Must have a template class name and a source value specified; " +
        "given (#{args.size} for 2)") if args.size < 2
    
      class_name = args[0]  
      data       = args[1]
      options    = ( args[2] ? args[2] : {} )
    
      config = Coral::Config.new(options, {
        :scope  => self,
        :search => 'coral::default'  
      })
      value = Coral::Template.render(class_name, data, config)
    end
    return value
  end
end
