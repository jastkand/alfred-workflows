#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'json'
require 'time'

RELEVANT_PROJECT_IDS = (ENV['RELEVANT_PROJECT_IDS'] || '').split('|')
TOGGL_API_KEY = ENV['TOGGL_API_KEY']
IGNORED_TIME_ENTRY = (ENV['IGNORED_TIME_ENTRY'] || '').split('|')

project_name = ARGV[0]

def fetch_time_entries(time)
  params = {
    start_date: Time.new(time.year, time.month, time.day).iso8601,
    end_date: time.iso8601
  }

  uri = URI.parse('https://www.toggl.com/api/v8/time_entries')
  uri.query = URI.encode_www_form(params)

  request = Net::HTTP::Get.new(uri)
  request.basic_auth(TOGGL_API_KEY, 'api_token')

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end

  {
    status: response.code.to_i,
    data: JSON.parse(response.body)
  }
end

def normalized_time_entries(time)
  entires_response = fetch_time_entries(time)

  return [] if entires_response[:status] != 200

  entires_response[:data].each_with_object([]) do |entry, result|
    next unless RELEVANT_PROJECT_IDS.include?(entry['pid'].to_s)
    result << entry['description']
  end
end

def generate_standup
  now = Time.now
  yesterday = Time.new(now.year, now.month, now.day) - 1

  [
    {
      title: 'Yesterday',
      entries: normalized_time_entries(yesterday)
    },
    {
      title: 'Today',
      entries: normalized_time_entries(Time.now)
    }
  ]
end

def print_entries(title, entries)
  print title
  print "\n- TBD" if entries.empty?

  entries.uniq.each do |entry|
    next if IGNORED_TIME_ENTRY.include?(entry)
    print "\n"
    print "- #{entry}"
  end
end

def print_line_break
  print "\n"
end

def render_standup(standup)
  standup.each_with_index do |item, index|
    print_entries(item[:title], item[:entries])

    print_line_break if index < standup.size - 1
  end
end

render_standup(generate_standup)
