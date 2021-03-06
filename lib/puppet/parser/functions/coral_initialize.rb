#
# coral_initialize.rb
#
# This function loads all of the Coral Ruby library files and, if requested,
# loads the included hiera_backend library overrides that provide more granular
# processing and translation of string data coming in from Hiera.
#
module Puppet::Parser::Functions
  newfunction(:coral_initialize, :doc => <<-EOS
This function loads all of the Coral Ruby library files and, if requested,
 loads the included hiera_backend library overrides that provide more granular
 processing and translation of string data coming in from Hiera.
    EOS
) do |args|
    lib_dir = File.join(File.dirname(__FILE__), '..', '..', '..')
    
    require_files  = lambda do |base_path|
      if File.exists?(base_path)
        Dir.glob(File.join(base_path, '*.rb')).each do |file|
          require file
        end
        Dir.glob(File.join(base_path, 'template', '*.rb')).each do |file|
          require file
        end  
      end  
    end
    
    # Include Coral core library files
    require_files.call(File.join(lib_dir, 'coral'))
    
    Coral.backtrace do
      Coral::Config.set_property('coral::time', Time.now.to_i)
      
      # Include Hiera extensions
      require File.join(lib_dir, 'hiera_backend')
      
      # Include Coral extensions
      Puppet::Node::Environment.new.modules.each do |mod|
        if mod.name != 'coral'
          require_files.call(File.join(mod.path, 'lib', 'coral'))
        end      
      end      
    end
  end
end
