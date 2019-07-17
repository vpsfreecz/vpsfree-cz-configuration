module ConfCtl
  module Pattern
    # @param pattern [String]
    # @param name [String]
    def self.match?(pattern, name)
      File.fnmatch?(pattern, name, File::FNM_EXTGLOB)
    end
  end
end
