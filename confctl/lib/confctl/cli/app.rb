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
        pins.desc 'Manage software pins files'
        pins.command :file do |f|
          f.desc 'List configured sw pins'
          f.arg_name '[file [sw]]'
          f.command :ls do |c|
            c.action &Command.run(Swpins::File, :list)
          end

          f.desc 'Manage git sw pins'
          f.command :git do |git|
            git.desc 'Add git sw pins'
            git.arg_name '<file> <sw> <url> <ref>'
            git.command :add do |c|
              c.action &Command.run(Swpins::File, :git_add)
            end

            git.desc 'Delete git sw pins'
            git.arg_name '<file> <sw>'
            git.command :del do |c|
              c.action &Command.run(Swpins::File, :git_delete)
            end

            git.desc 'Set git sw pins'
            git.command :set do |set|
              set.desc 'Set to git ref'
              set.arg_name '<file> <sw> <ref>'
              set.command :ref do |c|
                c.action &Command.run(Swpins::File, :git_set_ref)
              end

              set.desc 'Set to git branch'
              set.arg_name '<file> <sw> <branch>'
              set.command :branch do |c|
                c.action &Command.run(Swpins::File, :git_set_branch)
              end

              set.desc 'Set to git tag'
              set.arg_name '<file> <sw> <tag>'
              set.command :tag do |c|
                c.action &Command.run(Swpins::File, :git_set_tag)
              end
            end
          end
        end
      end
    end
  end
end
