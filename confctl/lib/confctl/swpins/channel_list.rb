module ConfCtl
  class Swpins::ChannelList < Array
    # @param channel_dir [String]
    # @param file_dir [String]
    # @param pattern [String]
    def initialize(channel_dir, file_dir, pattern: '*')
      Dir.glob(File.join(channel_dir, '*.json')).each do |f|
        name = File.basename(f, '.json')
        self << Swpins::Channel.new(f, file_dir) if Pattern.match?(pattern, name)
      end
    end
  end
end
