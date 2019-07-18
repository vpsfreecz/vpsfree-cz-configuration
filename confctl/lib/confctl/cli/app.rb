require 'gli'

module ConfCtl::Cli
  class App
    include GLI::App

    def self.get
      cli = new
      cli.setup
      cli
    end

    def self.run
      cli = get
      exit(cli.run(ARGV))
    end

    def setup
      Thread.abort_on_exception = true

      program_desc 'Manage vpsFree.cz cluster configuration and deployments'
      subcommand_option_handling :normal
      preserve_argv true
      arguments :strict
      hide_commands_without_desc true

      desc 'Manage software pins'
      command :swpins do |pins|
        pins.desc 'Manage software pins channels'
        pins.command :channel do |ch|
          ch.desc 'List configured sw pins'
          ch.arg_name '[channel [sw]]'
          ch.command :ls do |c|
            c.action &Command.run(Swpins::Channel, :list)
          end

          ch.desc 'Create a new channel'
          ch.arg_name '<channel>'
          ch.command :new do |c|
            c.action &Command.run(Swpins::Channel, :create)
          end

          ch.desc 'Delete channel'
          ch.arg_name '<channel>'
          ch.command :del do |c|
            c.desc 'Keep specs from the channel in files'
            c.switch 'keep-specs', default_value: true

            c.action &Command.run(Swpins::Channel, :delete)
          end

          git_commands(ch, Swpins::Channel, 'channel')
        end

        pins.desc 'Manage software pins files'
        pins.command :file do |f|
          f.desc 'List configured sw pins'
          f.arg_name '[file [sw]]'
          f.command :ls do |c|
            c.action &Command.run(Swpins::File, :list)
          end

          f.desc 'List configured sw pins'
          f.arg_name '[file [sw]]'
          f.command :ls do |c|
            c.action &Command.run(Swpins::File, :list)
          end

          git_commands(f, Swpins::File, 'file')

          f.desc 'Managed channelled sw pins'
          f.command :channel do |ch|
            ch.desc 'Assign file to channel'
            ch.arg_name '<file> <channel>'
            ch.command :use do |c|
              c.action &Command.run(Swpins::File, :channel_use)
            end
          end

          f.desc 'Managed channelled sw pins'
          f.command :channel do |ch|
            ch.desc 'Detach channel from file'
            ch.arg_name '<file> <channel>'
            ch.command :detach do |c|
              c.desc 'Keep specs from the channel'
              c.switch 'keep-specs', default_value: true

              c.action &Command.run(Swpins::File, :channel_detach)
            end
          end
        end
      end
    end

    protected
    def git_commands(cmd, klass, arg_name)
      cmd.desc 'Manage git sw pins'
      cmd.command :git do |git|
        git.desc 'Add git sw pins'
        git.arg_name "<#{arg_name}> <sw> <url> <ref>"
        git.command :add do |c|
          c.action &Command.run(klass, :git_add)
        end

        git.desc 'Delete git sw pins'
        git.arg_name "<#{arg_name}> <sw>"
        git.command :del do |c|
          c.action &Command.run(klass, :git_delete)
        end

        git.desc 'Set git sw pins'
        git.command :set do |set|
          set.desc 'Set to git ref'
          set.arg_name "<#{arg_name}> <sw> <ref>"
          set.command :ref do |c|
            c.action &Command.run(klass, :git_set_ref)
          end

          set.desc 'Set to git branch'
          set.arg_name "<#{arg_name}> <sw> <branch>"
          set.command :branch do |c|
            c.action &Command.run(klass, :git_set_branch)
          end

          set.desc 'Set to git tag'
          set.arg_name "<#{arg_name}> <sw> <tag>"
          set.command :tag do |c|
            c.action &Command.run(klass, :git_set_tag)
          end
        end
      end
    end
  end
end
