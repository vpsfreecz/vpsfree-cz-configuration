require 'json'

module ConfCtl
  class Swpins::Channel
    # @return [String]
    attr_reader :path

    # @return [String]
    attr_reader :name

    # @return [Array<Swpins::Specs::Base>]
    attr_reader :specs

    # @return [String]
    attr_reader :file_dir

    # @param channel_dir [String]
    # @param name [String]
    # @param file_dir [String]
    # @return [Swpins::Channel]
    def self.by_name(channel_dir, name, file_dir)
      new(File.join(channel_dir, "#{name}.json"), file_dir)
    end

    # @param path [String]
    # @param file_dir [String]
    def initialize(path, file_dir)
      @path = path
      @name = File.basename(path, '.json')
      @file_dir = file_dir
    end

    def parse
      @specs = Hash[JSON.parse(File.read(path), symbolize_names: true).map do |name, spec|
        [name.to_s, Swpins::Spec.for(spec[:type].to_sym).new(name, spec, spec[:options])]
      end]
    end

    # @param spec [Swpins::Specs::Base]
    def add_spec(spec)
      specs[spec.name] = spec
    end

    # @param pattern [String]
    # @return [Array<Swpins::Specs::Base>] deleted specs
    def delete_specs(pattern)
      ret = []

      specs.delete_if do |name, spec|
        if Pattern.match?(pattern, name)
          ret << spec
          true
        else
          false
        end
      end

      ret
    end

    # @return [Hash<Swpins::File, Array<Swpins::Specs::Base>>]
    def file_specs
      ret = {}

      Swpins::FileList.new(file_dir).each do |file|
        file.parse
        specs = file.specs.detect { |s| s.channel == name }
        ret[file] = specs if specs.any?
      end

      ret
    end

    def save
      tmp = "#{path}.new"

      File.open(tmp, 'w') do |f|
        f.puts(JSON.pretty_generate(specs))
      end

      File.rename(tmp, path)
    end

    def create
      @specs = {}
      save
    end

    # @param new_name [String]
    def rename(new_name)
      orig_path = path
      @name = new_name
      @path = File.join(File.dirname(path), "#{new_name}.json")
      save
      File.unlink(orig_path)
    end

    def delete
      File.unlink(path)
    end
  end
end
