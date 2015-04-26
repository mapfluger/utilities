require 'lps'
require './processmaker'
reader, writer = ProcessMaker.child_process_connect

puts "#{$PROGRAM_NAME}, #{Process.pid} is starting now"
$stdout.flush
count = 0
while true do
  begin
    status = Timeout::timeout(5) do
      begin 
        hash = reader.gets 
      end while hash.to_i != Time.now.to_i
      writer.write "1ack#{count}\n"
      puts reader.gets
      writer.write "2ack#{count}\n"
      puts reader.gets
      writer.write "3ack#{count}\n"
      puts reader.gets
      writer.write "4ack#{count}\n"
      count += 1
    end
  rescue Timeout::Error => e
    $stderr.puts "failed to connect parent"
    retry
    raise e
  end
end

sleep 15
puts "#{$PROGRAM_NAME}, #{Process.pid} is closing now"
reader.close
writer.close
