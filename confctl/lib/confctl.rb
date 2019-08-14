require 'require_all'

module ConfCtl
  def self.root
    File.realpath(File.join(File.dirname(__FILE__), '../../'))
  end

  def self.asset(name)
    File.join(root, 'confctl', 'assets', name)
  end
end

require_rel 'confctl/*.rb'
