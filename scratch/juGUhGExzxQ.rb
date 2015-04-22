require './PDPAaRjeg'
include ProcessMaker

reader, writer = subProcessConnect

# def hello(source, expect_input)
#   puts "[child] Hello from #{source}"
#   if expect_input
#     reader = IO.for_fd(source.split(',')[0].to_i)
#     writer  = IO.for_fd(source.split(',')[1].to_i)
#     ObjectSpace.each_object(IO) { |f| puts "child: #{f.fileno}" unless f.closed? || f.fileno <= 2}
#     from_parents = reader.gets
#     puts from_parents
#     #p writer.methods
#     writer.write "sent from child process2\n"
#     writer.flush
#   else
#     puts "[child] No stdin, or stdin is same as parent's"
#   end
#   $stderr.puts "[child] Hello, standard error"
#   puts "[child] DONE"
#   sleep 25
#   puts "still here"
# end

# def hello2()
#   puts "starting hello2"
#   ObjectSpace.each_object(IO) { |f| puts "inhello2: #{f.fileno}" unless f.closed? || f.fileno <= 2}
#   puts "[child] Hello from within file"
#   if true
#     #reader = IO.for_fd(source.split(',')[0].to_i)
#     #writer  = IO.for_fd(source.split(',')[1].to_i)
#     ObjectSpace.each_object(IO) { |f| puts "child: #{f.fileno}" unless f.closed? || f.fileno <= 2}
#     #from_parents = reader.gets
#    # puts from_parents
#     #p writer.methods
#    # writer.write "sent from child process2\n"
#    # writer.flush
#   else
#     puts "[child] No stdin, or stdin is same as parent's"
#   end
#   $stderr.puts "[child] Hello, standard error"
#   puts "[child] DONE"
#   sleep 25
#   puts "still here"
# end

# hello2