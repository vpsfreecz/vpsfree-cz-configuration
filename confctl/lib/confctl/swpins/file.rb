require 'json'

module ConfCtl
  class Swpins::File
    # @return [String]
    attr_reader :path

    # @return [String]
    attr_reader :name

    # @return [Array<Swpins::Specs::Base>]
    attr_reader :specs

    # @return [Array<String>]
    attr_reader :channels

    # @param path [String]
    def initialize(path)
      @path = path
      @name = File.basename(path, '.json')
    end

    def parse
      json = JSON.parse(File.read(path), symbolize_names: true)
      @specs = Hash[json.map do |k, v|
        name = k.to_s
        spec = Swpins::Spec.for(v[:type].to_sym).new(name, v, v[:options])
        [name, spec]
      end]
      @channels = @specs.each_value.map(&:channel).compact.uniq
    end

    # @param spec [Swpins::Specs::Base]
    def add_spec(spec)
      specs[spec.name] = spec
    end

    # @param pattern [String]
    # @yieldparam spec [Swpins::Specs::Base]
    # @yieldreturn [Boolean] true to delete the spec
    # @return [Array<Swpins::Specs::Base>] deleted specs
    def delete_specs(pattern)
      ret = []

      specs.delete_if do |name, spec|
        if Pattern.match?(pattern, name) && (block_given? ? yield(spec) : true)
          ret << spec
          true
        else
          false
        end
      end

      ret
    end

    # @param channel [Swpins::Channel]
    def use_channel(channel)
      channel.specs.each do |spec_name, chan_spec|
        new_spec = chan_spec.clone
        new_spec.channel = channel.name
        specs[spec_name] = new_spec
      end

      channels << channel.name unless channels.include?(channel.name)
    end

    # @param channel [Swpins::Channel]
    # @param add_new [Boolean] add new specs
    # @param override [Boolean] override existing specs
    def update_channel(channel, add_new: true, override: false)
      channel.specs.each do |spec_name, chan_spec|
        file_spec = specs[spec_name]

        next if !add_new && file_spec.nil?
        next if !override && (!file_spec.channel || file_spec.channel != channel.name)

        new_spec = chan_spec.clone
        new_spec.channel = channel.name
        specs[spec_name] = new_spec
      end
    end

    # @param channel [Swpins::Channel]
    # @param keep_specs [Boolean]
    def detach_channel(channel, keep_specs: false)
      channel.specs.each do |spec_name, chan_spec|
        next unless specs.has_key?(spec_name)

        if keep_specs
          specs[spec_name].channel = nil
        else
          specs.delete(spec_name)
        end
      end
    end

    # @param old_name [String]
    # @param new_name [String]
    def rename_channel(old_name, new_name)
      specs.each do |name, spec|
        spec.channel = new_name if spec.channel == old_name
      end
    end

    # @param name [String]
    def has_channel?(name)
      channels.include?(name)
    end

    def save
      tmp = "#{path}.new"

      File.open(tmp, 'w') do |f|
        f.puts(JSON.pretty_generate(specs))
      end

      File.rename(tmp, path)
    end
  end
end
