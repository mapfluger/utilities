require 'lps'
require './processmaker'

reader, writer = ProcessMaker.child_process_connect

puts "#{$PROGRAM_NAME}, #{Process.pid} is starting now"
$stdout.flush



LPS.interval(4).loop do 
  puts reader.gets
  writer.write "ack\n"
  puts reader.gets
  writer.write "ack\n"
  puts reader.gets
  writer.write "ack\n"
  puts reader.gets
  writer.write "ack\n"
  #writer.flush
end
sleep 15
puts "#{$PROGRAM_NAME}, #{Process.pid} is closing now"
reader.close
writer.close