reader1, writer1 = IO.pipe
reader2, writer2 = IO.pipe
ObjectSpace.each_object(IO) { |f| puts "origin: #{f.fileno}" unless f.closed? || f.fileno <= 2}

pid = fork do
  reader1.close
  writer2.close
  #puts reader2.close_on_exec?
  #writer1.puts "sent from child process1"
  #from_parent = reader2.gets
  ObjectSpace.each_object(IO) { |f| puts "childpre: #{f.fileno}" unless f.closed? || f.fileno <= 2}
  require_relative 'juGUhGExzxQ'
  sleep 1
  exec %Q</opt/chef/embedded/bin/ruby -r ./juGUhGExzxQ.rb -e 'hello("#{reader2.fileno},#{writer1.fileno}", true)'>
end
#test = {name: 'no'}
# Parent code
writer1.close
reader2.close
writer2.write "sent from parent process\n"
writer2.flush

from_child = reader1.gets
puts from_child

ObjectSpace.each_object(IO) { |f| puts "parent: #{f.fileno}" unless f.closed? || f.fileno <= 2}
puts pid
#Process.wait(pid)
