require "readline"
require "socket"

class Rlnc
  def self.start(args)
    obj = self.new
    hostname, port = obj.parse_args(args)
    obj.prepare
    begin
      obj.run(hostname, port)
    ensure
      obj.post_process
    end
  end

  def initialize
    @histfile = ""
    @history = [] of String
  end

  def usage(flag)
    out = flag ? STDOUT : STDERR
    out.puts "Usage: rlnc hostname port"
    exit(flag ? 0 : 1)
  end

  def parse_args(args)
    usage false unless args.size == 2
    args
  end

  def prepare
    @histfile = File.expand_path("~/.rlnc_history")
    File.open(@histfile, "r") do |f|
      f.flock_shared do
        f.each_line do |line|
          LibReadline.add_history line.chomp
        end
      end
    end
  rescue
    # ignore
  end

  def post_process
    prev = nil
    File.open(@histfile, "a", 0o600) do |f|
      f.flock_exclusive do
        @history.each do |line|
          f.puts line unless line.empty? || line == prev
          prev = line
        end
      end
    end
  end

  def run(hostname, port)
    sock = TCPSocket.new(hostname, port)
    r, w = IO.pipe
    child = Process.fork do
      r.close
      while true
        line = Readline.readline("", true)
        next unless line
        sock.puts line
        w.puts line
      end
    end
    Signal::INT.trap do
      child.kill
    end
    w.close
    spawn do
      while line = r.gets
        @history.push line
      end
    end
    spawn do
      while line = sock.gets
        puts line
      end
      child.kill
    end
    child.wait
  end
end

Rlnc.start(ARGV)
