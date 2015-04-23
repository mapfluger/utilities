module ProcessMaker
  def process_initialize(file_name)
    reader1, writer1 = IO.pipe
    reader2, writer2 = IO.pipe
    parent_writer = writer2.fileno
    parent_reader = reader1.fileno
    child_writer = writer1.fileno
    child_reader = reader2.fileno

    # ObjectSpace.each_object(IO) { |f| puts "origin: #{f.fileno}" unless f.closed? || f.fileno <= 2}

    pid = fork do
      reader1.close
      writer2.close
      exec %Q<ruby ./#{file_name} "#{reader2.fileno},#{writer1.fileno}">
    end

    # Parent code
    writer1.close
    reader2.close
    writer2.write "sent from parent process #{$PROGRAM_NAME}, #{Process.pid}\n"
    writer2.flush

    from_child = reader1.gets
    puts from_child

    # ObjectSpace.each_object(IO) { |f| puts "parent: #{f.fileno}" unless f.closed? || f.fileno <= 2}
    # puts pid
    # Process.wait(pid)
    return {name: file_name, pid: pid, parent_writer: parent_writer, parent_reader: parent_reader, child_writer: child_writer, child_reader: child_reader}
  end

  def sub_process_connect
    fail "No args!" if ARGV.length < 1
    arg = ARGV.last.to_s
    reader = IO.for_fd(arg.split(',')[0].to_i)
    writer  = IO.for_fd(arg.split(',')[1].to_i)
    # ObjectSpace.each_object(IO) { |f| puts "header: #{f.fileno}" unless f.closed? || f.fileno <= 2}
    from_parent = reader.gets
    puts from_parent
    writer.write "sent from child process #{$PROGRAM_NAME}, #{Process.pid}\n"
    writer.flush
    return reader, writer
  end

  def parent_process_connect(hash_info)
    reader = IO.for_fd(hash_info[:parent_reader])
    writer  = IO.for_fd(hash_info[:parent_writer])
    return reader, writer
  end
end


if $PROGRAM_NAME == __FILE__
  include ProcessMaker
  return_values = process_initialize("childprocesstest.rb")
  puts return_values
  reader, writer = parent_process_connect return_values
  return_values2 = process_initialize("childprocesstest.rb")
  puts return_values2
  return_values3 = process_initialize("childprocesstest.rb")
  puts return_values3
  return_values4 = process_initialize("childprocesstest.rb")
  puts return_values4
  return_values5 = process_initialize("childprocesstest.rb")
  puts return_values5
  # ObjectSpace.each_object(IO) { |f| puts "parentfinal: #{f.fileno}" unless f.closed? || f.fileno <= 2}
end
