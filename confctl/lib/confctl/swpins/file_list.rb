module ConfCtl
  class Swpins::FileList < Array
    # @param dir [String]
    # @param pattern [String]
    def initialize(dir, pattern: '*')
      Dir.glob(File.join(dir, '*.json')).each do |f|
        name = File.basename(f, '.json')
        self << Swpins::File.new(f) if Pattern.match?(pattern, name)
      end
    end
  end
end
