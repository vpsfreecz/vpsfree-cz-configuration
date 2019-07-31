require 'confctl/cli/command'
require 'confctl/cli/swpins/utils'

module ConfCtl::Cli
  class Swpins::Channel < Command
    DIR = File.join(Dir.pwd, 'swpins/channels')

    include Swpins::Utils

    def list
      puts sprintf('%-30s %-25s %-6s %s', 'CHANNEL', 'SW', 'TYPE', 'PIN')

      each_channel_spec(args[0] || '*', args[1] || '*') do |chan, spec|
        puts sprintf(
          '%-30s %-25s %-6s %s',
          chan.name, spec.name, spec.type, spec.version
        )
      end
    end

    def create
      require_args!('channel')
      chan = ConfCtl::Swpins::Channel.new(
        File.join(DIR, "#{args[0]}.json"),
        Swpins::File::DIR
      )
      chan.create
    end

    def rename
      require_args!('channel', 'new-channel')

      old_name = args[0]
      new_name = args[1]

      chan = channel_list('*').detect { |chan| chan.name == old_name }
      fail "Channel '#{args[0]}' not found" if chan.nil?

      chan.parse
      chan.rename(new_name)

      each_file('*') do |file|
        if file.has_channel?(old_name)
          puts "Renaming channel #{old_name} to #{new_name} in file #{file.name}"
          file.rename_channel(old_name, new_name)
          file.save
        end
      end
    end

    def delete
      require_args!('channel')

      each_channel(args[0]) do |chan|
        each_file('*') do |file|
          if file.has_channel?(chan.name)
            puts "Detaching channel #{chan.name} from file #{file.name}"
            file.detach_channel(chan, keep_specs: opts['keep-specs'])
            file.save
          end
        end

        chan.delete
      end
    end

    def git_add
      require_args!('channel', 'sw', 'url', 'ref')
      chan_pattern, sw, url, ref = args

      spec = ConfCtl::Swpins::Specs::Git.new(sw, {}, url: url)
      spec.prefetch(ref: ref)

      each_channel(chan_pattern) do |chan|
        puts "Adding #{spec.name} to channel #{chan.name}"
        chan.add_spec(spec)
        chan.save

        each_file('*') do |file|
          if file.has_channel?(chan.name)
            puts "Adding #{spec.name} to file #{file.name}"
            file.update_channel(chan, add_new: true, override: true)
            file.save
          end
        end
      end
    end

    def git_delete
      require_args!('channel', 'sw')
      chan_pattern, sw_pattern = args

      each_channel(chan_pattern) do |chan|
        specs = chan.delete_specs(sw_pattern)
        specs.each do |spec|
          puts "Deleting #{spec.name} from channel #{chan.name}"
        end
        chan.save if specs.any?

        each_file('*') do |file|
          if file.has_channel?(chan.name)
            file.delete_specs(sw_pattern) do |spec|
              puts "Deleting #{spec.name} from file #{file.name}"
              spec.channel == chan.name
            end
            file.save
          end
        end
      end
    end

    def git_set_ref
      require_args!('channel', 'sw', 'ref')
      git_set(*args[0..2])
    end

    def git_set_branch
      require_args!('channel', 'sw', 'branch')
      git_set(*args[0..1], "refs/heads/#{args[2]}")
    end

    def git_set_tag
      require_args!('channel', 'sw', 'tag')
      git_set(*args[0..1], "refs/tags/#{args[2]}")
    end

    protected
    def git_set(chan_pattern, sw_pattern, ref)
      channels = []

      each_channel_spec(chan_pattern, sw_pattern) do |chan, spec|
        puts "Updating #{spec.name} to #{ref} in channel #{chan.name}"
        spec.prefetch(ref: ref)
        channels << chan unless channels.include?(chan)
      end

      channels.each(&:save)

      channels.each do |chan|
        each_file('*') do |file|
          if file.has_channel?(chan.name)
            puts "Updating channel #{chan.name} in file #{file.name}"
            file.update_channel(chan, add_new: false, override: false)
          end
          file.save
        end
      end
    end
  end
end
