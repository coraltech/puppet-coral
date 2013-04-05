#
# config_initialized.rb
#
# This function checks if Hiera is fully configured and ready to query.
#
module Puppet::Parser::Functions
  newfunction(:config_initialized, :type => :rvalue, :doc => <<-EOS
This function checks if Hiera is fully configured and ready to query.
    EOS
) do |args|
    options = ( args[0] ? args[0] : {} )
    
    config = Coral::Config.new(options, {
      :scope     => self,
      :init_fact => 'hiera_ready'  
    })  
    return Coral::Config.initialized?(config)
  end
end
