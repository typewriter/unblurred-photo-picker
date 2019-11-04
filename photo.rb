#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'
require 'tmpdir'

class Photo
  attr_accessor :filename
  attr_accessor :kurtosis
  attr_accessor :skewness
  attr_accessor :entropy

  def initialize(filename)
    @filename = filename
    result = `identify -format "{ \"kurtosis\": %[kurtosis], \"standard_deviation\": %[standard-deviation], \"skewness\": %[skewness], \"entropy\": %[entropy] }" "#{filename}"`
    result_hash = YAML.load(result)

    @kurtosis = result_hash['kurtosis'].to_f
    # @standard_deviation = result_hash['standard_deviation'].to_f
    @skewness = result_hash['skewness'].to_f
    @entropy = result_hash['entropy'].to_f
  end

  def standard_deviation
    return @standard_deviation if @standard_deviation

    Dir.mktmpdir("unblurred") { |dir|
      `convert "#{filename}" -canny 0x1+10%+30% "#{dir}/edge.png"`
      result = `identify -format "{ \"kurtosis\": %[kurtosis], \"standard_deviation\": %[standard-deviation], \"skewness\": %[skewness], \"entropy\": %[entropy] }" "#{dir}/edge.png"`
      result_hash = YAML.load(result)
      @standard_deviation = result_hash['standard_deviation'].to_f
    }
    @standard_deviation
  end

  def calc_similarity(photo)
    result = `compare -format "%[distortion]" -metric PHASH "#{@filename}" "#{photo.filename}" NULL: 2>/dev/null`
    result.to_f
  end
end


def inspector(directory)
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
end

def select(photos, directory)
  max_sd = photos.map { |e| e.standard_deviation }.max
  duplicate_photos = photos.select { |e| e.standard_deviation != max_sd }

  duplicate_photos.each { |e|
    STDERR.puts "重複: #{File.basename(e.filename)}"
    files = Dir::glob("#{File.dirname(e.filename)}#{File::SEPARATOR}#{File.basename(e.filename, '.*')}.*")
    files.each { |file|
      FileUtils.mv(file, directory)
    }
  }
end

def selector(directory)
  duplicates_to = File.join(directory, 'duplicates')
  Dir::mkdir(duplicates_to) if !Dir.exist?(duplicates_to)

  STDERR.puts "重複画像は#{duplicates_to}に移動します．"

  photos = []
  files = Dir::glob(File.join(directory, '*.jpg'), File::FNM_CASEFOLD).sort
  files.each_with_index { |filename, i|
    STDERR.puts "#{i+1}/#{files.size} (#{sprintf('%.1f', (i+1) / files.size.to_f * 100)}%)"

    photo = Photo.new(filename)

    if photos.size == 0 || photos.last.calc_similarity(photo) < 10
      photos << photo
      next
    end

    select(photos, duplicates_to)
    photos = [photo]
  }

  select(photos, duplicates_to)
end

def usage
  STDERR.puts 'Usage: ./photo.rb mode directory'
  STDERR.puts
  STDERR.puts '  mode:      mode (inspector/selector)'
  STDERR.puts '  directory: directory'
end

if ARGV.size < 2
  usage
  exit
end

mode = ARGV[0]
directory = ARGV[1]

if mode == "selector"
  selector(directory)
elsif mode == "inspector"
  inspector(directory)
else
  usage
end

# photos = []
# STDERR.puts "processing #{directory}"
# Dir::glob(File.join(directory, '*.jpg'), File::FNM_CASEFOLD).sort.each { |filename|
#   photos << Photo.new(filename)
#   STDERR.puts "#{filename}: #{photos.last.inspect}"
#   STDERR.puts "  #{photos.last.calc_similarity(photos[-2])}" if photos.size >= 2
# }

