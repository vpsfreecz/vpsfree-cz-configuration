require 'json'

module ConfCtl
  class Swpins::Specs::Git < Swpins::Specs::Base
    handle :git

    def version
      opts[:rev][0..8]
    end

    # @param override_opts [Hash]
    # @option override_opts [String] :ref
    def prefetch(override_opts = {})
      json = `nix-prefetch-git --quiet #{opts[:url]} #{override_opts[:ref] || opts[:rev]}`

      if $?.exitstatus != 0
        fail "nix-prefetch-git failed with status #{$?.exitstatus}"
      end

      opts.update(JSON.parse(json.strip, symbolize_names: true))
      self.channel = nil
    end
  end
end
