module ConfCtl::Cli
  module Swpins::Utils
    def file_list(pattern)
      ConfCtl::Swpins::FileList.new(Swpins::File::DIR, pattern: pattern)
    end

    def each_file(file_pattern)
      file_list(file_pattern).each do |file|
        file.parse
        yield(file)
      end
    end

    def each_file_spec(file_pattern, sw_pattern)
      each_file(file_pattern) do |file|
        file.specs.each do |name, spec|
          yield(file, spec) if ConfCtl::Pattern.match?(sw_pattern, name)
        end
      end
    end

    def channel_list(pattern)
      ConfCtl::Swpins::ChannelList.new(Swpins::Channel::DIR, Swpins::File::DIR, pattern: pattern)
    end

    def each_channel(chan_pattern)
      channel_list(chan_pattern).each do |chan|
        chan.parse
        yield(chan)
      end
    end

    def each_channel_spec(chan_pattern, sw_pattern)
      each_channel(chan_pattern) do |chan|
        chan.specs.each do |name, spec|
          yield(chan, spec) if ConfCtl::Pattern.match?(sw_pattern, name)
        end
      end
    end
  end
end
