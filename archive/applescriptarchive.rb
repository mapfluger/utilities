# load ENV['RAKE_SYSTEM']

%w{shell-helper common terminal-helper}.each{|slack_gem|
  $:.push File.join(ENV['SLACK_GEM_HOME'], "#{slack_gem}/lib")
}
require 'shell-helper'
require 'safe/io'
require 'rake'
require 'fileutils'
require 'json'
require 'thread'

include ShellHelper::Shell
include TerminalHelper::TerminalLogging

desc "Deploy all machines in dependency order in parallel"
multitask :multi_deploy => [:clean_log_dir]

desc "Ups machines serially, then provisions all machine in parallel"
task :deploy => [:clean_log_dir, :up, :provision]

desc "Deploy all machines in dependency order in parallel"
multitask :multi_dev_deploy => [:clean_log_dir]

desc "Ups machines serially, then provisions all machine in parallel"
task :dev_deploy => [:clean_log_dir, :dev_up, :provision]

desc "Destroy all machine_names in reverse dependency order"
task :destroy => [:clean_log_dir]

desc "Shows statuses of available machines"
task :status do
  status
end

task :clean_log_dir do
  clean_log_dir  
end

def machine_names
  @machine_names
end

def lock
 @lock = Mutex.new if @lock.nil?
 @lock
end

def deployment_time
  @deployment_time
end

def terminal_id
  lock.lock
      if @terminal_id.nil?
        if [ `uname -s` == "Darwin" ] and `ps aux` =~ /iTerm/ ? true : false and false    
          script = %/
          tell application "iTerm"
          activate
          make new terminal
        end tell
        /
        system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten
        puts "Launching new iTerm window...\n"
      else
        script = '
        tell application "terminal"
          activate      
          set windowInfo to do script ""
        end tell
        '
        puts "Launching new Terminal window...\n"
        @terminal_id = %x(osascript <<EOD\n#{script}\nEOD).gsub(/\s+/m, ' ').strip.split(" ")[5]
      end
    end
  lock.unlock
@terminal_id
end

def tab_hash(machine)
  @tab_hash = Hash.new if @tab_hash.nil? || @tab_hash.empty?
  @tab_hash[machine] = @tab_hash.length + 1  if !@tab_hash.has_key? machine
  @tab_hash[machine]
end

def deployed_machines
  @deployed_machines = [] if @deployed_machines.nil?
  @deployed_machines
end

def provisioned_machines
  @provisioned_machines = [] if @provisioned_machines.nil?
  @provisioned_machines
end

def rake_file_path
  if @rake_file_path.nil?
    @rake_file_path = "#{Rake.application.rakefile}"
    raise "this should only be loaded by a rake file!\n\twas called by: #{@rake_file_path}" if @rake_file_path == '/'
  end
  @rake_file_path
end

def vagrant_file_path
  vagrant_path = nil
  if ENV['VAGRANT_ENV'] && ENV['VAGRANT_DIR']
    vagrant_path = ENV['PROJECT_HOME'] + "/infrastructure/vagrant/#{ENV['VAGRANT_ENV']}/#{ENV['VAGRANT_DIR']}/Vagrantfile"
  else
    vagrant_path = rake_file_path
  end

  vagrant_path
end

def run_gradle_tasks(tasks)
  unless tasks.nil?
    product_dir = ENV['PROJECT_HOME'] + "/product"

    Dir.chdir(product_dir) do
      tasks.each { |task|
        raise "Failed to build artifact while executing gradle task #{task}." unless shell_true?("gradle #{task}")

        ENV["#{task.upcase}_VERSION"] = "#{product_dir}/artifact_versions/#{task}.version"
      }
    end
  end
end

def log_dir
  if @log_dir.nil?
    @log_dir = File.expand_path('logs', File.dirname(vagrant_file_path))
    Safe::IO.action(@log_dir) do
      FileUtils.mkdir_p @log_dir unless File.exist?(@log_dir)
    end
  end
  @log_dir
end

def clean_log_dir
  Dir.glob("#{log_dir}/**/*") {|file|
    FileUtils.rm_f file if File.exist? file
  }
end

def clean_vagrant(machine)
  puts "Cleaning vagrant files for #{machine}"
  machine_dir = "#{File.dirname(vagrant_file_path)}/.vagrant/machines/#{machine}"
  Dir.glob("#{machine_dir}/**/*") {|file|
    FileUtils.rm_f file if File.exists? file
  }
end

def html_log_report
  @html_log_report = "#{log_dir}/index.html" if @html_log_report.nil?
  @html_log_report
end

def add_log_to_report(log_file)
  Safe::IO.action(html_log_report) do
    needs_header = false
    needs_header = true unless File.exist?(html_log_report)
    File.open(html_log_report, "a") { |file|
      if needs_header
        file.write(<<-EOS
          <!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
          <html xmlns ="http://www.w3.org/1999/xhtml">
            <head>
              <meta content="text/html;charset=utf-8" http-equiv="Content-Type"/>
              <title>Vagrant Logs</title>
            </head>
            <body>
          EOS
        )
      end
      file.write("<p><a href='#{File.basename(log_file)}'>#{File.basename(log_file)}</a></p>")
    }
  end
end

at_exit {
  write_html_log_report_footer
}

def write_html_log_report_footer
  if @write_html_log_report_footer.nil?
    Safe::IO.action(html_log_report) do
      File.open(html_log_report, "a") { |file|
        file.write(<<-EOS
            </body>
          </html>
          EOS
        )
        @write_html_log_report_footer = true
      }
    end
  end
end

def provider
  if @provider_name.nil?
    @provider_name = vagrant_file_path[/#{@root_dir}\/\w*[\-|\w]*[\/]?vagrant\/(\w+)\//,1]
  end
  @provider_name
end

def machine_state_exist?(machine_name)
  File.exist?(File.expand_path(".vagrant/machines/#{machine_name}/#{provider}/id", File.dirname(vagrant_file_path)))
end

def deploy_task(machine_name, dependencies=[], deploy_type=nil, build_tasks=[])
  @deployment_time = Time.new.getlocal.strftime("%Y%m%d-%H%M%S") if @deployment_time.nil?

  if @machine_names.nil?
    @machine_names = []
  end

  dependencies_prov = dependencies.collect{ |dependency| "provision_#{dependency}".to_sym }

  dependencies = dependencies.collect{ |dependency| "deploy_#{dependency}".to_sym }

  machine_names.push(machine_name)

  desc "Creates and starts the #{machine_name} machine"
  task "up_#{machine_name}".to_sym do
    up_machine(machine_name)
  end

  desc "Builds artifact and creates and starts the #{machine_name} machine"
  task "dev_up_#{machine_name}".to_sym do
    run_gradle_tasks(build_tasks)
    up_machine(machine_name)
  end

  task :up => "up_#{machine_name}".to_sym
  task :dev_up => "dev_up_#{machine_name}".to_sym

  desc "Provisions the #{machine_name} machine or reloads latest post-provision snapshot"
  multitask "provision_#{machine_name}".to_sym => dependencies_prov do
    if deploy_type == "snapshot"
      unless has_snapshot?(machine_name, "latest_provision")
        puts "No post-provision snapshot found for #{machine_name} to restore to, running provision instead."
        provision_machine(machine_name)
      else
        restore_snapshot(machine_name, "latest_provision")
      end
    else
      provision_machine(machine_name)
    end
  end

  desc "Provisions the #{machine_name} machine"
  multitask "provision_f_#{machine_name}".to_sym => dependencies_prov do
    provision_machine(machine_name)
  end

  desc "Resumes the suspended #{machine_name} machine"
  task "resume_#{machine_name}" do
    resume_machine(machine_name)
  end

  desc "Suspends the #{machine_name} machine"
  task "suspend_#{machine_name}" do
    suspend_machine(machine_name)
  end

  desc "Halts the #{machine_name} machine"
  task "halt_#{machine_name}" do
    halt_machine(machine_name)
  end

  desc "Reloads the #{machine_name} machine"
  task "reload_#{machine_name}" do
    reload_machine(machine_name)
  end

  task :halt => "halt_#{machine_name}".to_sym

  multitask :provision => "provision_#{machine_name}".to_sym do
     script = %Q/
        tell application "terminal"
          if window id #{@terminal_id} exists then
            repeat with j from 1 to number of tabs of window id #{terminal_id}
              if "ERROR" is in (custom title of tab j of window id #{terminal_id} as string) then exit repeat
              if j = count of tabs in window id #{terminal_id} then close window id #{terminal_id} 
              if not exists window id #{terminal_id} then return "Closing terminal window..." as string
            end repeat
          end if
        end tell
      /   
      closeMessage = %x(osascript <<EOD\n#{script}\nEOD)
      puts closeMessage if ! closeMessage.empty? 
  end

  desc "Bring up all dependencies of #{machine_name} and load snapshot or provision against #{machine_name}"
  multitask "deploy_#{machine_name}".to_sym => dependencies do
    if machine_state_exist?(machine_name) and deploy_type == "snapshot" 
      unless has_snapshot?(machine_name, "latest_provision")
        puts "No post-provision snapshot found to restore to, running provision instead."
        provision_machine(machine_name)
      else
        restore_snapshot(machine_name, "latest_provision")
      end
    else
      provision_machine(machine_name)
    end
  end
  multitask "deploy_#{machine_name}".to_sym

  desc "Destroy #{machine_name}"
  multitask "destroy_#{machine_name}".to_sym do
    destroy_machine(machine_name)
  end

  desc "SSH to #{machine_name}"
  task "ssh_#{machine_name}".to_sym do
    ssh_machine(machine_name)
  end

  desc "Takes a snapshot for the #{machine_name} machine"
  task "take_snapshot_#{machine_name}".to_sym do
    snapshot_machine(machine_name)
  end

  desc "Restores the #{machine_name} to specified snapshot"
  task "restore_snapshot_#{machine_name}".to_sym, [:snapshot_name] do |t, args|
    snapshot_name = args[:snapshot_name]
    unless snapshot_name.nil?
      restore_snapshot(machine_name, snapshot_name)
    else
      puts "Please specify the name of the snapshot to restore to with restore_snapshot_machine[snapshot_name]."
    end
  end

  desc "Bring up all dependencies of #{machine_name} and provision using locally built artifacts."
  multitask "dev_deploy_#{machine_name}".to_sym => dependencies do
    dev_provision_machine(machine_name, build_tasks)
  end

  desc "Deletes the specified snapshot for the #{machine_name} machine"
  task "delete_snapshot_#{machine_name}".to_sym, [:snapshot_name] do |t, args|
    snapshot_name = args[:snapshot_name]
    unless snapshot_name.nil?
      delete_snapshot(machine_name, snapshot_name)
    else
      puts "Please specify the name of the snapshot to delete with delete_snapshot_machine[snapshot_name]."
    end
  end

  desc "Lists the snapshots for the #{machine_name} machine"
  task "list_snapshot_#{machine_name}".to_sym do
    list_snapshot(machine_name)
  end  

  task "prov_snapshot_#{machine_name}".to_sym do
    prov_snapshot_machine(machine_name)
  end

  task "clean_vagrant_#{machine_name}".to_sym do
    clean_vagrant(machine_name)
  end

  task :clean_vagrant => "clean_vagrant_#{machine_name}".to_sym
  task :prov_snapshot => "prov_snapshot_#{machine_name}".to_sym
  multitask :multi_deploy => "deploy_#{machine_name}".to_sym
  multitask :multi_dev_deploy => "dev_deploy_#{machine_name}".to_sym
  task :destroy => "destroy_#{machine_name}".to_sym
end

def destroy_machine(machine)
  delete_all_snapshots(machine)
  vagrant_action(machine, 'destroy', '-f')
end

def up_machine(machine, berks_switch='-bu')
  vagrant_action(machine, 'up', "--no-provision #{berks_switch}")
  deployed_machines << machine
end

def dev_provision_machine(machine_name, tasks)
  run_gradle_tasks(tasks)
  provision_machine(machine_name)
end

def provision_machine(machine, berks_switch='-bc')
  unless provisioned_machines.include?(machine)
    up_machine(machine) unless machine_state_exist?(machine)
    if [ `uname -s` == "Darwin" ] and `ps aux` =~ /iTerm/ ? true : false and false
      vagrant_action_new_iterm_window(machine, 'provision', berks_switch)
    elsif `ps aux` =~ /Terminal/ ? true : false
      vagrant_action_new_terminal_window(machine, 'provision', berks_switch)
    else
      vagrant_action(machine, 'provision', berks_switch)
    end
    provisioned_machines << machine
  end
  deployed_machines << machine
end

def resume_machine(machine)
  vagrant_action(machine, 'resume')
end

def suspend_machine(machine)
  vagrant_action(machine, 'suspend')
end

def reload_machine(machine)
  vagrant_action(machine, 'reload')
end

def halt_machine(machine)
  vagrant_action(machine, 'halt')
end

def ssh_machine(machine)
  if machine_state_exist?(machine)
    Dir.chdir(File.dirname(vagrant_file_path)) do
      exec("#{ENV['VAGRANT_BIN']} ssh #{machine}")
    end
  else
    puts "The #{machine} machine has not been created. Run deploy_#{machine} to create it."
  end
end

def vagrant_action(machine, vagrant_command, vagrant_switches='')
  Dir.chdir(File.dirname(vagrant_file_path)) do
    log_file = "#{log_dir}/#{machine}.#{vagrant_command.gsub(/ /,'.')}.log"
    add_log_to_report(log_file)
    shell_command! "#{ENV['VAGRANT_BIN']} #{vagrant_command} #{machine} #{vagrant_switches} 2>&1 | tee #{log_file}; ( exit ${PIPESTATUS[0]} )", log_tag: "[-#{machine}-] "
  end
end

def prov_snapshot_machine(machine)
  if machine_state_exist?(machine)
    if provider == "virtualbox"
      branch = `git rev-parse --abbrev-ref HEAD`.chomp!
      head = `git rev-parse HEAD`.chomp!
      vagrant_action(machine, "snapshot take", "-n #{deployment_time} -d #{branch},#{head}")
      if has_snapshot?(machine, "latest_provision")
        vagrant_action(machine, "snapshot delete", "-n latest_provision")
      end
      vagrant_action(machine, "snapshot take", "-n latest_provision -d #{branch},#{head}")
    end
  else
    puts "The #{machine} machine has not been created. Run deploy_#{machine} to create it."
  end
end

def snapshot_machine(machine)
  if machine_state_exist?(machine)
    if provider == "virtualbox"
      branch = `git rev-parse --abbrev-ref HEAD`.chomp!
      head = `git rev-parse HEAD`.chomp!
      vagrant_action(machine, "snapshot take", "-n #{deployment_time} -d #{branch},#{head}")
    end
  else
    puts "The #{machine} machine has not been created. Run deploy_#{machine} to create it."
  end
end

def has_snapshot?(machine, snapshot_name)
  if machine_state_exist?(machine)
    Dir.chdir(File.dirname(vagrant_file_path)) do
      snapshots = `#{ENV['VAGRANT_BIN']} snapshot status #{machine}`
      snapshots.split("\n").each do |snapshot_line|
        if snapshot_line.split[1] == snapshot_name
          return true
        end
      end
    end
  else
    puts "The #{machine} machine has not been created. Run deploy_#{machine} to create it."
  end
  false
end

def restore_snapshot(machine, name)
  if machine_state_exist?(machine) and has_snapshot?(machine, name)
    vagrant_action(machine, "snapshot restore", "-n #{name}")
  else
    puts "Could not find snapshot #{name} for the #{machine} machine."
  end
end

def delete_snapshot(machine, name)
  if machine_state_exist?(machine) and has_snapshot?(machine, name)
    vagrant_action(machine, "snapshot delete", "-n #{name}")
  else
    puts "Could not find snapshot #{name} for the #{machine} machine."
  end
end

def list_snapshot(machine)
  if machine_state_exist?(machine)
    vagrant_action(machine, "snapshot status")
  else
    puts "The #{machine} machine has not been created. Run deploy_#{machine} to create it."
  end
end

def delete_all_snapshots(machine)
  if machine_state_exist?(machine)
    Dir.chdir(File.dirname(vagrant_file_path)) do
      puts "Deleting all snapshots for #{machine}, this may take a while..."
      snapshots = `#{ENV['VAGRANT_BIN']} snapshot status #{machine}`
      snapshots.split("\n").each do |snapshot_line|
        if snapshot_line.split[0] == "-"
          delete_snapshot(machine, snapshot_line.split[1])
        end
      end
    end
  else
    puts "The #{machine} machine has not been created. Run deploy_#{machine} to create it."
  end
end

def vagrant_action_new_terminal_window(machine, vagrant_command, vagrant_switches='')
  log_file = "#{log_dir}/#{machine}.#{vagrant_command.gsub(/ /,'.')}.log"
  env_vars = ""
  env_vars = req_env if defined? req_env
  newTab = %x(defaults read com.apple.terminal NSUserKeyEquivalents | grep "New Tab").split("\"")[3] ||= "@t"
  modifierNew  = '' 
  {'@' => 'command', '~' => 'option', '^' => 'control', '$' => 'shift'}.each do |key, value|
    if newTab.include? key
      newTab.delete! key
      if modifierNew.empty?
        modifierNew = value + " down"
      else
        modifierNew << ", " + value + " down"
      end
    end
  end 
  currentTab = tab_hash("#{machine}")
  script = %Q/
  tell application "Terminal"
    if not #{currentTab} = 1 and not exists tab #{currentTab} in window id #{terminal_id} then
      repeat while count of tabs in window id #{terminal_id} < #{currentTab}
        tell window id #{terminal_id} to activate
        set frontmost of window id #{terminal_id} to true
        tell application "System Events" to tell process "Terminal" to keystroke "#{newTab}" using {#{modifierNew}}
        delay 3
      end repeat
    end if
    if not "ERROR" is in (custom title of tab #{currentTab} of window id #{terminal_id} as string) then
      do script "cd #{File.dirname(vagrant_file_path)}" in tab #{currentTab} of window id #{terminal_id}
      do script "if [ -z \\$VISTACORE_PROJECT ]; then source #{ENV['PROJECT_HOME']}\/infrastructure\/set.env.sh; fi;" in tab #{currentTab} of window id #{terminal_id} 
      do script "rename_terminal #{machine}" in tab #{currentTab} of window id #{terminal_id}
      do script "clear" in tab #{currentTab} of window id #{terminal_id} 
      do script "#{ENV['VAGRANT_BIN']} #{vagrant_command} #{machine} #{vagrant_switches} 2>&1 | tee #{log_file}; ( exit ${PIPESTATUS[0]} )" in tab #{currentTab} of window id #{terminal_id} 
      delay 3
      repeat until not busy in tab #{currentTab} of window id #{terminal_id} 
        delay 10
      end repeat
    else
      do script "echo 'will not run #{vagrant_command} #{machine} because of error in this tab'" in tab #{currentTab} of window id #{terminal_id} 
    end if
  end tell
  /
  %x(osascript <<EOD\n#{script}\nEOD)
  if ! %x(cat #{log_file} | grep -iE "Chef never successfully|Vagrant failed|VM not created").empty? 
   script = %Q/
     tell application "Terminal"
       set os_version to do shell script "sw_vers -productVersion"
       if os_version >= 10.9 then
         display notification "#{machine} had an error on vagrant #{vagrant_command}." with title "ERROR: #{machine}"
       end if
       set custom title of tab #{currentTab} of window id #{terminal_id} to "ERROR:#{machine}"
       set background color of tab #{currentTab} of window id #{terminal_id} to "red"
      end tell
   /
  else
    script = %Q/
      set os_version to do shell script "sw_vers -productVersion"
      if os_version >= 10.9 then
        display notification "#{machine}'s vagrant #{vagrant_command} completed." with title "#{machine}"
      end if
    /
  end
  %x(osascript <<EOD\n#{script}\nEOD)
end

def vagrant_action_new_iterm_window(machine, vagrant_command, vagrant_switches='')
  log_file = "#{log_dir}/#{machine}.#{vagrant_command.gsub(/ /,'.')}.log"
  env_vars = ""
  env_vars = req_env if defined? req_env
  script = %/
tell application "iTerm"
  delay 3
  activate
  set deployTerm to (terminal (count of terminal))
  tell the deployTerm 
    set deploySession to (launch session "Deploy:#{machine}")
    tell the deploySession
      write text "cd #{File.dirname(vagrant_file_path)}"
      write text "source #{ENV['PROJECT_HOME']}\/infrastructure\/set.env.sh"
      write text "rename_terminal Deploy:#{machine}"
      write text "clear"
      write text "#{env_vars} #{ENV['VAGRANT_BIN']} #{vagrant_command} #{machine} #{vagrant_switches} 2>&1 | tee #{log_file}; ( exit ${PIPESTATUS[0]} )"
    end tell
  end tell
end tell
/
  
  system 'osascript', *script.split(/\n/).map { |line| ['-e', line] }.flatten

  puts "Launching process for #{machine} in separate tab...\n"
  sleep(1) until `ps -ef | grep \"#{ENV['VAGRANT_BIN']} #{vagrant_command} #{machine} #{vagrant_switches}\" | grep -v grep` != ""
  until `ps -ef | grep \"#{ENV['VAGRANT_BIN']} #{vagrant_command} #{machine} #{vagrant_switches}\" | grep -v grep` == ""
    puts "..\n"
    sleep(10)
  end
  puts "Process for #{machine} complete"
end

def status
  Dir.chdir(File.dirname(vagrant_file_path)) do
    shell_command! "#{ENV['VAGRANT_BIN']} status"
  end
end
