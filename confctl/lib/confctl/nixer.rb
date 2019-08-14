require 'bundix/nixer'

module ConfCtl
  class Nixer < Bundix::Nixer
    def serialize
      super
    rescue RuntimeError
      case obj
      when Numeric
        obj.to_s
      else
        raise
      end
    end
  end
end
