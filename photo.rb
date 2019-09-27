#!/usr/bin/env ruby

require 'yaml'

class Photo
  attr_accessor :filename
  attr_accessor :kurtosis
  attr_accessor :standard_deviation
  attr_accessor :skewness
  attr_accessor :entropy

  def initialize(filename)
    @filename = filename
    result = `identify -format "{ \"kurtosis\": %[kurtosis], \"standard_deviation\": %[standard-deviation], \"skewness\": %[skewness], \"entropy\": %[entropy] }" "#{filename}"`
    result_hash = YAML.load(result)

    @kurtosis = result_hash['kurtosis'].to_f
    @standard_deviation = result_hash['standard_deviation'].to_f
    @skewness = result_hash['skewness'].to_f
    @entropy = result_hash['entropy'].to_f
  end

  def calc_similarity(photo)
    result = `compare -format "%[distortion]" -metric PHASH "#{@filename}" "#{photo.filename}" NULL: 2>/dev/null`
    result.to_f
  end
end

directory = ARGV[0]

# photos = []
# STDERR.puts "processing #{directory}"
# Dir::glob(File.join(directory, '*.jpg'), File::FNM_CASEFOLD).sort.each { |filename|
#   photos << Photo.new(filename)
#   STDERR.puts "#{filename}: #{photos.last.inspect}"
#   STDERR.puts "  #{photos.last.calc_similarity(photos[-2])}" if photos.size >= 2
# }

puts <<STYLE
<style type="text/css">
table { border: 1px solid black; }
td { text-align: right; }
</style>
STYLE

puts "<TABLE>"
puts "<TR><TH>写真</TH><TH>類似度</TH><TH>Kurtosis</TH><TH>SD</TH><TH>Skewness</TH><TH>Entropy</TH></TR>"

photos = []
Dir::glob(File.join(directory, '*.jpg'), File::FNM_CASEFOLD).sort.each { |filename|
  photos << Photo.new(filename)
  puts "<TR>"
  puts "<TD><IMG src=\"#{filename}\" width=320></TD>"
  puts "<TD>#{photos.last.calc_similarity(photos[-2]) if photos.size >= 2}</TD>"
  puts "<TD>#{sprintf("%.2f", photos.last.kurtosis)}</TD>"
  puts "<TD>#{sprintf("%.2f", photos.last.standard_deviation)}</TD>"
  puts "<TD>#{sprintf("%.2f", photos.last.skewness)}</TD>"
  puts "<TD>#{sprintf("%.2f", photos.last.entropy)}</TD>"
  puts "</TR>"
  STDOUT.flush
  STDERR.puts "#{filename}"
}

puts "</TABLE>"
