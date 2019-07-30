module ConfCtl::Cli
  class Documentation < Command
    PID_FILE = '.mkdocs.pid'
    LOG_FILE = '.mkdocs.log'

    def start_server
      if File.exist?(PID_FILE)
        fail "Pid file #{PID_FILE} exists, is server already running?"
      end

      top = Process.fork do
        log = File.open(LOG_FILE, 'w')
        STDOUT.reopen(log)
        STDERR.reopen(log)
        STDIN.close

        Process.fork do
          File.open(PID_FILE, 'w') { |f| f.puts(Process.pid.to_s) }

          pid = Process.spawn('mkdocs', 'serve', '-a', 'localhost:8000')
          Signal.trap('USR1') { Process.kill('INT', pid) }
          Process.wait(pid)

          begin
            File.unlink(PID_FILE)
          rescue Errno::ENOENT
          end
        end
      end

      Process.wait(top)

      puts "Server running at http://localhost:8000"
      puts "Log file at #{LOG_FILE}"
      puts "Use '#{$0} docs stop' to stop the server"
    end

    def stop_server
      unless File.exist?(PID_FILE)
        fail 'Pid file not found'
      end

      puts 'Stopping server'
      pid = File.read(PID_FILE).strip.to_i
      Process.kill('USR1', pid)
    end
  end
end
