#require 'debugger'
require 'timeout'
class ProcessMaker
  attr_accessor :reader, :writer, :read_stderr, :info
  def initialize(file_name, keep_alive = false, temp = false)
    @reader, writer_child = IO.pipe
    reader_child, @writer = IO.pipe
    @read_stderr, write_stderr = IO.pipe
    @reader.sync = true
    @writer.sync = true
    @read_stderr.sync = true
    pid = fork do
      @reader.close
      @writer.close
      @read_stderr.close
      exec %Q<ruby ./#{file_name} "#{reader_child.fileno},#{writer_child.fileno},#{write_stderr.fileno}">
    end

    @info = {name: file_name, pid: pid, active: true, keep_alive: keep_alive, temp: temp}
    writer_child.close
    reader_child.close
    write_stderr.close
    @writer.write "sent from parent process #{$PROGRAM_NAME}, #{Process.pid}\n"
    @writer.flush
    begin
      status = Timeout::timeout(5) do
        from_child = @reader.gets
        puts from_child
      end
    rescue Timeout::Error => e
      $stderr.puts "failed to connect to child for #{@info[:name]}, #{@info[:pid]}"
      self.close
      raise e
    end
    self.waiter unless temp
  end

  def waiter
    Thread.new do
      Process.waitpid(@info[:pid])
      puts "THREADS: #{Thread.list.count}"
      if @info[:keep_alive] && @info[:active]
        self.reset
        self.waiter
      else
        puts "shutting down #{@info[:name]}, #{@info[:pid]}"
        self.close # maybe just shutdownlink
      end
    end
  end

  def reset
    temp = ProcessMaker.new(@info[:name], true, true)
    oldpid = @info[:pid]
    @reader.close unless @reader.closed?
    @writer.close unless @writer.closed?
    @read_stderr.close unless @read_stderr.closed?
    @reader = temp.reader
    @writer = temp.writer
    @read_stderr = temp.read_stderr
    @info = temp.info
    @info[:temp] = false
    puts "keeping alive now: #{@info[:name]}, new: #{@info[:pid]} old: #{oldpid}"
    temp = nil
  end

  def self.child_process_connect
    fail "No args!" if ARGV.length < 1
    ObjectSpace.each_object(IO) { |f| puts "sub_process_connect1: #{f.fileno}" if  !f.closed? && f.fileno > 2}
    puts "ARGV: #{ARGV.last.to_s.split(',')[0].to_i}, #{ARGV.last.to_s.split(',')[1].to_i}, #{ARGV.last.to_s.split(',')[2].to_i}"
    reader = IO.new(ARGV.last.to_s.split(',')[0].to_i)
    writer  = IO.new(ARGV.last.to_s.split(',')[1].to_i)
    new_stderr  = IO.new(ARGV.last.to_s.split(',')[2].to_i)
    reader.sync = true
    writer.sync = true
    new_stderr.sync = true
    $stderr.reopen(new_stderr)
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
    rescue Errno::ESRCH => e
      $stderr.puts "No such process for #{@info[:name]}, #{@info[:pid]}. Closing pipes if open"
      self.shut_down_link
      return false
    end
    begin
      Process.kill signal, @info[:pid]
    rescue Errno::ESRCH => e
      $stderr.puts "Failed to kill child for #{@info[:name]}, #{@info[:pid]}"
      return false
    end
    self.shut_down_link
    puts "Closed #{@info[:name]}, #{@info[:pid]}"
    return true
  end

  def status
    begin
      Process.kill 0, @info[:pid]
    rescue Errno::ESRCH => e
      $stderr.puts "No such process for #{@info[:name]}, #{@info[:pid]}. Closing pipes if open"
      self.shut_down_link
      return false
    end
    return true
  end

  def shut_down_link
    @reader.close unless @reader.closed?
    @writer.close unless @writer.closed?
    @read_stderr.close unless @read_stderr.closed?
    @info[:active] = false
    return true
  end

  def parent_conversation(conversation_array)
    tries = 0
    begin
      status = Timeout::timeout(1) do
        begin
          self.writer.write "#{Time.new.to_i}\n"
          verify = self.reader.gets
          puts "verify: #{verify}"
        end while verify != "ack#{Time.new.to_i}\n" #shouldnt ever be false
        conversation_array.each do |var|
          puts "sending: #{var}"
          self.writer.write "#{var}\n"
          verify = self.reader.gets
          puts verify
          #redo if verify != "ack#{var}\n" ############ need to verify data got through in different way
        end
      end
    rescue Timeout::Error => e
      $stderr.puts "failed to connect to child for #{self.info[:name]}, #{self.info[:pid]}"
      self.writer.write "#{Time.new.to_i}\n"
      tries += 1
      puts "tries #{tries}"
      if tries <= 10
        puts "tries #{tries}"
        retry
      else
        self.close # probably restart in practice
        raise e
      end
    end
  end

  def self.child_converstation(reader, writer, quantity, timeout_val = 30)
    return_val = Array.new
    begin
      status = Timeout::timeout(timeout_val) do
        begin
          time = reader.gets
          puts "time: #{time}"
        end while time.to_i != Time.now.to_i
        writer.write "ack#{Time.new.to_i}\n"
        quantity.times do
          verify = reader.gets
          return_val << verify[0..-2]
          writer.write "ack#{verify}"
        end
      end
    rescue Timeout::Error => e
      $stderr.puts "failed to connect parent"
      retry
      raise e
    end
    return return_val
  end
end

# test code!
if $PROGRAM_NAME == __FILE__ && ARGV.length == 0
  puts 'Basic test suite'
  #include ProcessMaker
  return_values1 = ProcessMaker.new("childprocesstest.rb")
  puts return_values1.info
  reader, writer = return_values1.parent_process_connect  # example of parent connections if you need their objects seperately, prefer obj.pipe
  # puts "reader autoclose: #{reader.autoclose?}"
  return_values2 = ProcessMaker.new("childprocesstest.rb", true)
  puts return_values2.info
  return_values3 = ProcessMaker.new("childprocesstest.rb", true)
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
  puts test2.info
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
  ObjectSpace.each_object(IO) { |f| puts "7: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "8: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "9: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "10: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "11: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "12: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "13: #{f.fileno}" if !f.closed? && f.fileno > 2}
  return_values2.info[:keep_alive] = false # option to let child die
  return_values3.close # kills child
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "14: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "15: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "16: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "17: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2
  ObjectSpace.each_object(IO) { |f| puts "18: #{f.fileno}" if !f.closed? && f.fileno > 2}
  sleep 2

  puts test2.status
  puts return_values3.status
  puts return_values3.status
  # puts `ps aux | grep ruby`
  $stdout.flush
  ObjectSpace.each_object(IO) { |f| puts "parentfinal19: #{f.fileno}" if !f.closed? && f.fileno > 2}
  $stdout.flush
elsif $PROGRAM_NAME == __FILE__ && ARGV.length != 0
  require 'lps'
  puts 'Conversation test suite'
  tester = ProcessMaker.new("conversationtest.rb", true)
  puts tester.info
  LPS.interval(4).loop do
    # begin
    #   status = Timeout::timeout(1) do
    #     if count == 3 || count == 4 || count == 6
    #       tester.writer.write "#{Time.new.to_i + 3}\n"
    #     else
    #       tester.writer.write "#{Time.new.to_i}\n"
    #     end
    #     puts tester.reader.gets
    #     tester.writer.write "status#{count}\n"
    #     puts tester.reader.gets
    #     tester.writer.write "threshold#{count}\n"
    #     puts tester.reader.gets
    #     tester.writer.write "frequency#{count}\n"
    #     puts tester.reader.gets
    #     count += 1
    #   end
    # rescue Timeout::Error => e
    #   $stderr.puts "failed to connect to child for #{tester.info[:name]}, #{tester.info[:pid]}"
    #   tester.writer.write "#{Time.new.to_i}\n"
    #   tries += 1
    #   if tries <= 10
    #     puts "tries #{tries}"
    #     retry
    #   else
    #     tester.close # probably restart in practice
    #     raise e
    #   end
    # end
    tester.parent_conversation ["status","threshold","frequency"]
    # sleep 10
  end
end
