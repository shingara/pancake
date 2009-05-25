module Pancake
  class Stack
    
    ## Add the bootloaders to the new application stack
    Pancake::Stack.on_inherit do |base|
      base.class_eval do
        class BootLoader
          extend ::Pancake::BootLoaderMixin
        end
        BootLoader.stack = self
        BootLoader.reset!
      end
    end # Pancake::Stack.on_inherit
    
  end # Stack
end # Pancake

#################### Define the bootloaders here #############################
