puts "7. PTY"
require 'pty'
$stdout.sync = true
# %Q</usr/bin/ruby -r ./juGUhGExzxQ.rb -e 'hello("popen", true)'
PTY.spawn('/usr/bin/ruby', '-r', './juGUhGExzxQ', '-e', 'hello("PTY", true)') do
  |output, input, pid|
  input.write("hello from parent\n")
  buffer = ""
  output.readpartial(1024, buffer) until buffer =~ /DONE/
  buffer.split("\n").each do |line|
    puts "[parent] output: #{line}"
  end
end
puts "---"