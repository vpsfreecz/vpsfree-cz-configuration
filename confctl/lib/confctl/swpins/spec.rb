module ConfCtl
  module Swpins::Spec
    # @param name [Symbol]
    # @param klass [Class]
    def self.register(name, klass)
      @specs ||= {}
      @specs[name] = klass
    end

    # @param name [Symbol]
    # @return [Class]
    def self.for(name)
      @specs[name]
    end
  end

  module Swpins::Specs ; end
end

require_rel 'specs'
