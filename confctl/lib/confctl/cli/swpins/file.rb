require 'confctl/cli/command'
require 'confctl/cli/swpins/utils'

module ConfCtl::Cli
  class Swpins::File < Command
    DIR = File.join(Dir.pwd, 'swpins/files')

    include Swpins::Utils

    def list
      puts sprintf('%-30s %-25s %-15s %-6s %s', 'FILE', 'SW', 'CHANNEL', 'TYPE', 'PIN')

      each_file_spec(args[0] || '*', args[1] || '*') do |file, spec|
        puts sprintf(
          '%-30s %-25s %-15s %-6s %s',
          file.name, spec.name, spec.channel || '-', spec.type, spec.version
        )
      end
    end

    def channel_use
      require_args!('file', 'channel')
      file_pattern, chan_pattern = args

      each_file(file_pattern) do |file|
        each_channel(chan_pattern) do |chan|
          puts "Using channel #{chan.name} in #{file.name}"
          file.use_channel(chan)
          file.save
        end
      end
    end

    def channel_detach
      require_args!('file', 'channel')
      file_pattern, chan_pattern = args

      each_file(file_pattern) do |file|
        each_channel(chan_pattern) do |chan|
          puts "Detaching channel #{chan.name} from #{file.name}"
          file.detach_channel(chan, keep_specs: opts['keep-specs'])
          file.save
        end
      end
    end

    def git_add
      require_args!('file', 'sw', 'url', 'ref')
      file_pattern, sw, url, ref = args

      spec = ConfCtl::Swpins::Specs::Git.new(sw, {}, url: url)
      spec.prefetch(ref: ref)

      each_file(file_pattern) do |file|
        puts "Adding #{spec.name} to #{file.name}"
        file.add_spec(spec)
        file.save
      end
    end

    def git_delete
      require_args!('file', 'sw')
      file_pattern, sw_pattern = args

      each_file(file_pattern) do |file|
        specs = file.delete_specs(sw_pattern)
        specs.each do |spec|
          puts "Deleting #{spec.name} from #{file.name}"
        end
        file.save if specs.any?
      end
    end

    def git_set_ref
      require_args!('file', 'sw', 'ref')
      git_set(*args[0..2])
    end

    def git_set_branch
      require_args!('file', 'sw', 'branch')
      git_set(*args[0..1], "refs/heads/#{args[2]}")
    end

    def git_set_tag
      require_args!('file', 'sw', 'tag')
      git_set(*args[0..1], "refs/tags/#{args[2]}")
    end

    protected
    def git_set(file_pattern, sw_pattern, ref)
      files = []

      each_file_spec(file_pattern, sw_pattern) do |file, spec|
        puts "Updating #{spec.name} to #{ref} in #{file.name}"
        spec.prefetch(ref: ref)
        files << file unless files.include?(file)
      end

      files.each(&:save)
    end
  end
end
