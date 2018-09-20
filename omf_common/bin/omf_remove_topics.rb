#!/usr/bin/env ruby

BIN_DIR = File.dirname(File.symlink?(__FILE__) ? File.readlink(__FILE__) : __FILE__)
TOP_DIR = File.join(BIN_DIR, '..')
$: << File.join(TOP_DIR, 'lib')

DESCR = %{
Remove a topic/queue or a set of topics/queues from RabbitMQ Broker.

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
type_to_remove = "topics"

op = OptionParser.new
op.banner = "Usage: #{op.program_name} [options] topic1 topic2 ...\n#{DESCR}\n"
op.on '-c', '--comms-url URL', "URL of communication server (e.g. http://<address>:15672)" do |u|
  base_url = u.gsub(/\/$/, "")
end

op.on '-t', '--type_to_remove EXCHANGES|QUEUES|CONNECTIONS', "Type of object to remove (Topics or Queues)" do |t|
  type_to_remove = t.downcase
end

op.on '-p', "--pattern PATTERN", "Regular expression with the pattern of the topic(s)/queue(s) names to delete. The script
              will remove all topics/queues which name follows the regular expression." do |p|
  pattern = p
end
op.on '-y', '--yes-delete', "Delete the topics/queues without asking for user permission" do
  yes_delete = true
end

op.on_tail('-h', "--help", "Show this message") { $stderr.puts op; exit }
op.parse(ARGV)

unless base_url && pattern
  $stderr.puts "ERROR: Missing declaration of --comms-url or pattern to remove\n\n"
  $stderr.puts op
  exit(-1)
end

def get_request(url)
  puts "GET #{url}\n"

  uri = URI.parse(url)
  http = Net::HTTP.new(address=uri.host, port=uri.port)

  request = Net::HTTP::Get.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  request.basic_auth 'testbed', 'testbed'

  response = http.request(request)

  body = JSON.parse(response.body)
  puts body
  body
end

def put_request(url, res_desc)
  puts "PUT all topics\n"

  uri = URI.parse(url)
  http = Net::HTTP.new(address=uri.host, port=uri.port)

  request = Net::HTTP::Put.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  request.basic_auth 'testbed', 'testbed'
  request.body = res_desc.to_json

  response = http.request(request)

  body = JSON.parse(response.body)
  puts body
  body
end

def filter_topics_with_pattern(topics, pattern)
  if pattern == "*"
    topics
  else
    topics.select { |topic| topic["name"] =~ /#{pattern}/ }
  end
end

def delete_request(url)
  puts "DELETE #{url}\n"

  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  request = Net::HTTP::Delete.new(uri.request_uri, initheader = {'Content-Type' =>'application/json'})
  request.basic_auth 'testbed', 'testbed'

  response = http.request(request)

  JSON.parse(response.body) if response.body
end

def ask_and_delete(base_url, type_to_remove, yes_delete, pattern)
  puts "Removing #{type_to_remove}"
  url = "#{base_url}/api/#{type_to_remove.downcase}"
  if type_to_remove.downcase != "connections"
    url = "#{url}/%2f"
  end

  topics = get_request(url)
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
      url = "#{base_url}/api/#{type_to_remove.downcase}"
      if type_to_remove.downcase != "connections"
        url = "#{url}/%2f"
      end
      url = "#{url}/#{encoded_name}"

      result = delete_request(url)
      puts result
    end
  end
end

ask_and_delete(base_url, type_to_remove, yes_delete, pattern)
