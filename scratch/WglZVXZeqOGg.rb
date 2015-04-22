require 'rbconfig'
require_relative 'juGUhGExzxQ'
require 'timeout'
#$stdout.sync = true

# def hello(source, expect_input)
#   puts "[child] Hello from #{source}"
#   if expect_input
#     puts "[child] Standard input contains: \"#{$stdin.readline.chomp}\""
#   else
#     puts "[child] No stdin, or stdin is same as parent's"
#   end
#   $stderr.puts "[child] Hello, standard error"
# end

THIS_FILE = File.expand_path(__FILE__)

#RUBY = File.join(Config::CONFIG['bindir'], Config::CONFIG['ruby_install_name'])
# :END:

if $PROGRAM_NAME == __FILE__
  pid = nil
  puts "4b. IO.popen"
  cmd = %Q</usr/bin/ruby -r ./juGUhGExzxQ.rb -e 'hello("popen", true)'>
  begin
    Timeout.timeout(5) do
      IO.popen(cmd, 'w+') do |subprocess|
        pid = subprocess.pid
        #subprocess.daemon
        #p subprocess.methods
        #subprocess.sync = true
        #Process.detach(subprocess.pid)
        subprocess.write("hello from parent")
        subprocess.close_write
        subprocess.read.split("\n").each do |l|
          puts "[parent] output: #{l}"
        end
        puts "[parent] child pid is #{subprocess.pid}"
        pid = subprocess.pid
       # puts "Killing subprocess1"
       # Process.kill(9, pid)
      end
      puts pid
      puts "---"
      sleep 1
      puts "Killing subprocess2"
      Process.kill(9, pid)
    end
  rescue Timeout::Error
    Process.kill 9, pid
    # collect status so it doesn't stick around as zombie process
    Process.wait pid
  end
  puts "#{server} child exited, pid = #{pid}"





  # IO.popen(cmd, 'w+') do |subprocess|
  #   #subprocess.daemon
  #   p subprocess.methods
  #   #subprocess.sync = true
  #   #Process.detach(subprocess.pid)
  #   subprocess.write("hello from parent")
  #   subprocess.close_write
  #   subprocess.read.split("\n").each do |l|
  #     puts "[parent] output: #{l}"
  #   end
  #   puts "[parent] child pid is #{subprocess.pid}"
  #   pid = subprocess.pid
  #   puts "Killing subprocess1"
  # Process.kill(9, pid)
  # end
  # puts pid
  # puts "---"
  # sleep 1
  # puts "Killing subprocess2"
  # Process.kill(9, pid)
end
