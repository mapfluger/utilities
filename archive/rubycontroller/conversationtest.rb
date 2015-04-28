require 'lps'
require './processmaker'
reader, writer = ProcessMaker.child_process_connect

puts "#{$PROGRAM_NAME}, #{Process.pid} is starting now"
$stdout.flush
while true do
  value = ProcessMaker.child_converstation(reader, writer, 3)
  p value
  # begin
  #   status = Timeout::timeout(5) do
  #     begin 
  #       hash = reader.gets 
  #       puts "hash: #{hash}"
  #     end while hash.to_i != Time.now.to_i
  #     writer.write "ack#{Time.new.to_i}\n"
  #     verify1 = reader.gets
  #     writer.write "ack#{verify1}"
  #     verify2 = reader.gets
  #     writer.write "ack#{verify2}"
  #     verify3 = reader.gets
  #     writer.write "ack#{verify3}"
  #   end
  # rescue Timeout::Error => e
  #   $stderr.puts "failed to connect parent"
  #   retry
  #   raise e
  # end
end

sleep 15
puts "#{$PROGRAM_NAME}, #{Process.pid} is closing now"
reader.close
writer.close
