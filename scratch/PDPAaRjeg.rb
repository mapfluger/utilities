
module ProcessMaker
  def processInitialize(file_name)
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
    writer2.write "sent from parent process\n"
    writer2.flush

    from_child = reader1.gets
    puts from_child

    ObjectSpace.each_object(IO) { |f| puts "parent: #{f.fileno}" unless f.closed? || f.fileno <= 2}
    puts pid
    #Process.wait(pid)
    return {name: file_name, pid: pid, parent_writer: parent_writer, parent_reader: parent_reader, child_writer: child_writer, child_reader: child_reader}
  end

  def subProcessConnect
    fail "No args!" if ARGV.length == 0
    arg = ARGV[0].to_s
    reader = IO.for_fd(arg.split(',')[0].to_i)
    writer  = IO.for_fd(arg.split(',')[1].to_i)
    ObjectSpace.each_object(IO) { |f| puts "header: #{f.fileno}" unless f.closed? || f.fileno <= 2}
    return reader, writer
  end
end


if $PROGRAM_NAME == __FILE__
  include ProcessMaker
  returnvalues = processInitialize("juGUhGExzxQ.rb")
  puts returnvalues
end
