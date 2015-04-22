
$stdout.sync = true

def hello(source, expect_input)
  puts "[child] Hello from #{source}"
  if expect_input
    puts "[child] Standard input contains: \"#{$stdin.readline.chomp}\""
  else
    puts "[child] No stdin, or stdin is same as parent's"
  end
  $stderr.puts "[child] Hello, standard error"
  puts "[child] DONE"
  sleep 15
  puts "still here"
end



IO.popen("-", "w+") do |subprocess|
  if subprocess.nil?             # child
    hello("popen(-)", true)
    exit
  else                        # parent
    subprocess.write("hello from parent")
    subprocess.close_write
    subprocess.read.split("\n").each do |l|
      puts "[parent] output: #{l}"
    end
    puts
  end
end
puts "---"