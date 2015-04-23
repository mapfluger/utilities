# require 'debugger'
class ProcessMaker
  attr_accessor :reader, :writer, :info
  def initialize(file_name)
    @reader, writer_child = IO.pipe
    reader_child, @writer = IO.pipe

    pid = fork do
      @reader.close
      @writer.close
      exec %Q<ruby ./#{file_name} "#{reader_child.fileno},#{writer_child.fileno}">
    end

    # Parent code
    writer_child.close
    reader_child.close
    @writer.write "sent from parent process #{$PROGRAM_NAME}, #{Process.pid}\n"
    @writer.flush

    from_child = @reader.gets
    puts from_child

    @info = {name: file_name, pid: pid, parent_writer: @writer, parent_reader: @reader}
    trap(:CHLD) do
      begin
        Process.wait
      rescue #Errno::ECHILD
      end
    end
    return @info
  end

  def self.sub_process_connect
    fail "No args!" if ARGV.length < 1
    arg = ARGV.last.to_s
    puts arg
    puts "arg: #{arg.split(',')[0].to_i}"
    puts "arg: #{arg.split(',')[1].to_i}"
    ObjectSpace.each_object(IO) { |f| puts "sub_process_connect1: #{f.fileno}" if  !f.closed? && f.fileno > 2}
    reader = IO.new(arg.split(',')[0].to_i)
    writer  = IO.new(arg.split(',')[1].to_i)
    ObjectSpace.each_object(IO) { |f| puts "sub_process_connect2: #{f.fileno}" if  !f.closed? && f.fileno > 2}
    from_parent = reader.gets
    puts from_parent
    writer.write "sent from child process #{$PROGRAM_NAME}, #{Process.pid}\n"
    writer.flush
    return reader, writer
  end

  def parent_process_connect
    return @reader, @writer
  end

  def restart_child(signal = 9)
    self.close(signal)
    ProcessMaker.new @info[:name]
  end

  def close(signal = 9)
    begin
      Process.kill 0, @info[:pid]
    rescue Errno::ESRCH => rescue_var
      $stderr.puts "No such process for #{@info[:name]}, #{@info[:pid]}. Closing pipes"
      @reader.close
      @writer.close
      return false
    end
    puts Process.kill 0, @info[:pid]
    puts @info[:pid]
    begin
      #Process.detach @info[:pid]
      Process.kill signal, @info[:pid]
    rescue Errno::ESRCH => rescue_var
      $stderr.puts "Failed to kill child for #{@info[:name]}, #{@info[:pid]}"
      return false
    end

    @reader.close
    @writer.close
    puts "Closed #{@info[:name]}, #{@info[:pid]}"
  end

  def status
    begin
      Process.kill 0, @info[:pid]
    rescue Errno::ESRCH => rescue_var
      $stderr.puts "No such process for #{@info[:name]}, #{@info[:pid]}. Closing pipes"
      @reader.close
      @writer.close
      return false
    end
    return true
  end
end

# test code!
if $PROGRAM_NAME == __FILE__
  #include ProcessMaker
  return_values1 = ProcessMaker.new("childprocesstest.rb")
  puts return_values1.info
  reader, writer = return_values1.parent_process_connect  # example of parent connections
  # puts "reader autoclose: #{reader.autoclose?}"
  #return_values2 = process_initialize("childprocesstest.rb")
  #puts return_values2
  #return_values3 = process_initialize("childprocesstest.rb")
  #puts return_values3
  #return_values4 = process_initialize("childprocesstest.rb")
  #puts return_values4
  #return_values5 = process_initialize("childprocesstest.rb")
  #puts return_values5
  ObjectSpace.each_object(IO) { |f| puts "parentfinal1: #{f.fileno}" if !f.closed? && f.fileno > 2}

  test = return_values1.restart_child
  puts test.info
  test1 = test.restart_child
  # puts `ps aux | grep ruby`
  puts test1.info
  test2 =  test1.restart_child
  puts 'before '
  puts test2.info
  puts 'here'
  ObjectSpace.each_object(IO) { |f| puts "parentfinal2: #{f.fileno}" if  !f.closed? && f.fileno > 2}
  sleep 10
  puts test2.status
  puts `ps aux | grep ruby`
  ObjectSpace.each_object(IO) { |f| puts "parentfinal3: #{f.fileno}" if !f.closed? && f.fileno > 2}
end
