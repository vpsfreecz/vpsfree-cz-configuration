require 'require_all'

module ConfCtl
  def self.root
    File.realpath(File.join(File.dirname(__FILE__), '../../'))
  end
end

require_rel 'confctl/*.rb'
