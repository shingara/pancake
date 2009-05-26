require 'set'
module Pancake
  module BootLoaderMixin
    include Enumerable
    class Base
      # :api: :public
      attr_accessor :stack, :config
      
      # Sets options for the bootloder
      # By including conditions in the bootloader when you declare it
      # You can selectively run bootloaders later
      # :api: private
      def self.options=(opts={}) # :nodoc:
        @options = opts
        @options[:level] ||= :default
      end
      
      # Provides access to the bootloader options
      # :api: private
      def self.options # :nodoc:
        @options ||= {}
      end
      
      def self.proc=(prc); @proc = prc; end
      def self.proc; @proc; end
      
      def initialize(stack, config)
        @stack, @config = stack, config
      end
      
      # Creates a new instance and runs it
      # :api: private
      def self.call(stack, config)
        new(stack, config).run!
      end
      
      # Checks the conditions with the options of the bootloader
      # To see if this one should be run
      # Only the central bootloaders with the conditions will be checked
      # :api: private
      def self.run?(conditions = {}) 
        opts = options
        if conditions.keys.include?(:only)
          return conditions[:only].all?{|k,v| opts[k] == v}
        end
        if conditions.keys.include?(:except)
          return conditions[:except].all?{|k,v| opts[k] != v}
        end
        true
      end
    end
    
    # Provides access to an individual bootloader
    # :api: public
    def [](name)
      _bootloaders[name]
    end
    
    # Add a bootloader.  Inside the block we're inside a class definition.  
    # Requirements: define a +run!+ method
    #
    # Example
    #   FooStack::BootLoader.add(:foo) do
    #     def run!
    #       # stuff
    #     end
    #   end
    # 
    # :api: public
    def add(name, opts = {}, &block)
      _bootloaders[name] = Class.new(Pancake::BootLoaderMixin::Base, &block)
      _bootloaders[name].proc = block
      raise "You must declare a #run! method on your bootloader" unless _bootloaders[name].method_defined?(:run!)
      before = opts[:before]
      after  = opts[:after]
      
      if opts[:level]
        levels << opts[:level]
        levels.uniq!
      end
      
      # If there are no before or after keys, add it to the central bootloaders
      if before
        _bootloader_map[before][:before] << name
      elsif after
        _bootloader_map[after][:after] << name
      else
        _central_bootloaders << name unless _central_bootloaders.include?(name)
      end
      _bootloaders[name].options = opts
      _bootloaders[name]
    end      
    
    # Runs the bootloaders in order
    # :api: private 
    def run!(conditions = {}) # :nodoc:
      unless conditions.keys.include?(:only) || conditions.keys.include?(:except)
        conditions[:only] = {:level => :default}
      end
      each(conditions) do |name, bl|
        bl.call(stack, :foo)
      end
    end
    
    # Set the stack that this bootloader is responsible for.
    # :api: private
    def stack=(stack) # :nodoc:
      @stack = stack
    end
    
    # Access to the stack that this bootloader is responsible for
    # :api: public
    def stack
      @stack
    end
    
    # Resets the bootloaders on the stack
    # :api: public
    def reset!
      _central_bootloaders.clear
      _bootloaders.clear
      _bootloader_map.clear
    end
    
    # Copies bootloaders from another bootloader to this one
    # :api: public
    def copy_to(other)
      levels.each do |level|
        each(:only => {:level => level}) do |n, bl|
          other.add(n, bl.options, &bl.proc)
        end
      end
    end
    
    # Yields each bootloader in order along with it's name
    # 
    # Example
    #   FooStack::BootLoader.each do |name, bootloader|
    #     # do stuff
    #   end
    # 
    # :api: public
    def each(conditions = {})
      _map_bootloaders(_central_bootloaders, conditions).each do |n|
        yield n, _bootloaders[n]
      end
    end
  
    # Tracks the central bootloaders.  The central bootloaders are like the spine of the bootloader system
    # All other bootloaders hang off either before or after the central bootloaders
    # :api: private
    def _central_bootloaders # :nodoc:
      @_central_bootloaders ||= []
    end
    
    # Keeps track of bootloaders to run before or after other bootloaders
    # :api: private
    def _bootloader_map # :nodoc:
      @_bootloader_map ||= Hash.new{|h,k| h[k] = {:before => [], :after => []}}
    end
    
    # Provide access to the raw bootloader classes
    # :api: private
    def _bootloaders # :nodoc:
      @_bootloaders ||= {}
    end
    
    private
    # Map out the bootloaders by name to run.
    # :api: private
    def _map_bootloaders(*names)
      conditions = Hash === names.last ? names.pop : {}
      names.flatten.map do |name|
        if _bootloaders[name].run?(conditions)
          r = []
          r << _map_bootloaders(_bootloader_map[name][:before])
          r << name
          r << _map_bootloaders(_bootloader_map[name][:after])
        end
      end.flatten.compact
    end
    
    def levels
      @levels ||= [:default]
    end

  end # BootLoaders
end # Pancake