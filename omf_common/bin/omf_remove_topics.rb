#!/usr/bin/env ruby

BIN_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
TOP_DIR = File.join(BIN_DIR, '..')
$: << File.join(TOP_DIR, 'lib')

DESCR = %{
Remove a topic or a set of topics from RabbitMQ Broker.

}

# The following is to work around a bug in activesupport triggered by
# the JWT library which is used only in the AMQP transport, os it
# fails quietly if that library is not installed in XMPP deployments
begin; require 'json/jwt'; rescue Exception; end


require 'optparse'
require 'omf_common'
require 'highline/import'
require 'net/http'
require 'cgi'

OP_MODE = :development

opts = {
  communication: {
    #url: 'xmpp://srv.mytestbed.net',
    #auth: {}
  },
  eventloop: { type: :em},
  logging: {
    level: 'info'
  }
}

base_url = nil
pattern = nil
yes_delete = false

op = OptionParser.new
op.banner = "Usage: #{op.program_name} [options] topic1 topic2 ...\n#{DESCR}\n"
op.on '-c', '--comms-url URL', "URL of communication server (e.g. http://user:password@my.server.com)" do |u|
  base_url = u.gsub(/\/$/, "")
end
op.on '-p', "--pattern PATTERN", "Regular expression with the pattern of the topic(s) names to delete. The script
              will remove all topics which name follows the regular expression." do |p|
  pattern = Regexp.new(p)
end
op.on '-y', '--yes-delete', "Delete the topics without asking for user permission" do
  yes_delete = true
end

op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
op.parse(ARGV)

unless base_url && pattern
  $stderr.puts "ERROR: Missing declaration of --comms-url or pattern to remove\n\n"
  $stderr.puts op
  exit(-1)
end

def list_topics_with_rest(url)
  puts "Listing all topics\n"

  uri = URI.parse(url)
  http = Net::HTTP.new(address=uri.host, port=uri.port)

  request = Net::HTTP::Get.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  request.basic_auth 'testbed', 'testbed'

  response = http.request(request)

  body = JSON.parse(response.body)
  puts body
  body
end

def filter_topics_with_pattern(topics, pattern)
  topics.select { |topic| topic["name"] =~ pattern }
end

def delete_topic_with_rest(url)
  puts "Delete topic with rest. URL: #{url}\n"

  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Delete.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  request.basic_auth 'testbed', 'testbed'

  response = http.request(request)

  JSON.parse(response.body) if response.body
end


url = "#{base_url}/api/exchanges/%2f"

topics = list_topics_with_rest(url)
filtered_topics = filter_topics_with_pattern(topics, pattern)

unless yes_delete
  puts "Topics to delete:"
  puts filtered_topics
end

require "highline/import"
input = ask "Do you really want to delete the topics? (y/N)"

if input.downcase == "y"
  for topic in filtered_topics
    encoded_name = CGI::escape(topic["name"])
    url = "#{base_url}/api/exchanges/%2f/#{encoded_name}"
    result = delete_topic_with_rest(url)
    puts result
  end
end