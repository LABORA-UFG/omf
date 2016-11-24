#!/usr/bin/env ruby

abort "Please use Ruby 1.9.3 or higher" if RUBY_VERSION < "1.9.3"

require 'optparse'
require 'fileutils'

if Process.uid!=0
  abort "You have to be root to install the OMF EC config file.
You also need to have the omf_ec gem installed as root and have RVM installed as root (if you don't use system ruby)."
end

options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename($PROGRAM_NAME)} [options]"
  opts.on("-c", "--configfile", "Install config file template in /etc/omf_ec/config.yml") do |c|
    options[:config] = c
  end
  opts.on_tail("-h", "--help", "Show this message") do
    puts opts
    exit
  end
end

optparse.parse!
if options.empty?
  puts optparse
  exit
end

spec = Gem::Specification.find_by_name("omf_ec")
gem_root = spec.gem_dir

if options[:config]
  puts "Copying configuration file..."
  FileUtils.mkdir_p "/etc/omf_ec"
  FileUtils.cp "#{gem_root}/config/config.yml", "/etc/omf_ec/config.yml"
  FileUtils.chmod 0644, "/etc/omf_ec/config.yml"
  puts "done."
end