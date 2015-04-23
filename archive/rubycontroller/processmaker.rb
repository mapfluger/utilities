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

    Thread.new {
      Process.waitpid(@info[:pid])
      @reader.close unless @reader.closed?
      @writer.close unless @writer.closed?
      @info[:active] = false
    }

    @info = {name: file_name, pid: pid, parent_writer: @writer, parent_reader: @reader, active: true}
  end

  def self.sub_process_connect
    fail "No args!" if ARGV.length < 1
    arg = ARGV.last.to_s
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
      $stderr.puts "No such process for #{@info[:name]}, #{@info[:pid]}. Closing pipes if open"
      @reader.close unless @reader.closed?
      @writer.close unless @writer.closed?
      return false
    end
    puts Process.kill 0, @info[:pid]
    puts @info[:pid]
    begin
      Process.kill signal, @info[:pid]
    rescue Errno::ESRCH => rescue_var
      $stderr.puts "Failed to kill child for #{@info[:name]}, #{@info[:pid]}"
      return false
    end

    @reader.close unless @reader.closed?
    @writer.close unless @writer.closed?
    puts "Closed #{@info[:name]}, #{@info[:pid]}"
  end

  def status
    begin
      Process.kill 0, @info[:pid]
    rescue Errno::ESRCH => rescue_var
      $stderr.puts "No such process for #{@info[:name]}, #{@info[:pid]}. Closing pipes if open"
      @reader.close unless @reader.closed?
      @writer.close unless @writer.closed?
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
  return_values2 = ProcessMaker.new("childprocesstest.rb")
  puts return_values2.info
  return_values3 = ProcessMaker.new("childprocesstest.rb")
  puts return_values3.info
  return_values4 = ProcessMaker.new("childprocesstest.rb")
  puts return_values4.info
  return_values5 = ProcessMaker.new("childprocesstest.rb")
  puts return_values5.info
  return_values6 = ProcessMaker.new("childprocesstest.rb")
  puts return_values6.info
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
  #sleep 20
  ObjectSpace.each_object(IO) { |f| puts "3: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "4: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "5: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "6: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2

  puts test2.status
  # puts `ps aux | grep ruby`
  $stdout.flush
  ObjectSpace.each_object(IO) { |f| puts "parentfinal3: #{f.fileno}" if !f.closed? && f.fileno > 2}
  $stdout.flush
end
