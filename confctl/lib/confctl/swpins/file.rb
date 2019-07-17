require 'json'

module ConfCtl
  class Swpins::File
    # @return [String]
    attr_reader :path

    # @return [String]
    attr_reader :name

    # @return [Array<Swpins::Specs::Base>]
    attr_reader :specs

    # @param path [String]
    def initialize(path)
      @path = path
      @name = File.basename(path, '.json')
    end

    def parse
      json = JSON.parse(File.read(path), symbolize_names: true)
      @specs = Hash[json.map do |name, spec|
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

    def save
      tmp = "#{path}.new"

      File.open(tmp, 'w') do |f|
        f.puts(JSON.pretty_generate(specs))
      end

      File.rename(tmp, path)
    end
  end
end
