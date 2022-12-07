require 'byebug'
=begin
  TODO
  -[x] If line ends with ",", it should be merged with the previous line
  -[x] If there is a "class_name" token, partner should be the string that comes after
  -[] Multiple files support
  -[] If multiple files are given, remove belongs_to that is not required
=end

require 'active_support/inflector'

class Main
  def self.run
    extension = ARGV[0]
    case extension
    when '.rb'
      include RubyParser
    when '.go'
      include GoParser
    end
    filenames = Dir["#{ARGV[1]}**/*#{extension}"].reject {|fn| File.directory?(fn) }
    output = filenames.map{|filename| Main.new.run(filename)}.reject(&:nil?).uniq
    puts output
  end

  BLACKLIST = Set.new %w'ActiveSupportConcern'

  def read_file(filename)
    file = File.open(filename, "r")
    data = file.read
    file.close
    data  
  end

  module GoParser
    def preprocess(file)
      file.
        encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').
        split("\n").
        map(&:strip).
        join("\n").
        gsub(",\n", ', ')
    end
  
    def run(filename)
      filter = ARGV[2]
      file = preprocess(read_file(filename))
      package = file.split("package ")[1].split("\n")[0]
      partners = file.split("import (\n")[1]
      return if partners.nil?
      partners.split(")")[0].split("\n").map do |partner|
        if !filter.nil?
          next unless partner.include?(filter)
          partner = partner.gsub(filter, '')
        end
        partner = partner.strip
        partner = "\"#{partner.split("\"")[1...].join}\"" if partner.include? "\""
        next if partner.empty?
        next if package.include?("test")
        next if partner.include?("github.com")
        "#{package} -- #{partner} : > include"
      end.reject(&:nil?)
    end
  end

  module RubyParser
    def preprocess(file)
      file.
        encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '').
        split("\n").
        map(&:strip).
        join("\n").
        gsub(",\n", ', ').
        split("\n")
    end
  
    def run(filename)
      lines = preprocess(read_file(filename))

      klass = ''
      lines.map do |line|
        tokens = line.strip.split(' ')
        relation = tokens.shift
  
        next if tokens.include? 'through:'
  
        if %w'class module'.include? relation
          klass = "#{klass}#{tokens.shift}"
          klass = klass.gsub('::', '')
          next
        end
  
        next unless %w'belongs_to has_one include extend has_many'.include? relation
  
        partner = tokens.shift  
        
        class_name_index = tokens.index('class_name:')
        partner = tokens[class_name_index + 1] unless class_name_index.nil?
        
        partner = partner[1...partner.length] if partner[0] == ':'
        partner = partner[0...partner.length-1] if partner[partner.length - 1] == ','
        
        # partner = partner.singularize if %w'has_many'.include? relation
        next if %w'has_many has_one'.include? relation
        
        partner = partner.gsub(':', '')
        partner = partner.gsub("'", '')
        partner = partner.camelize
        
        next if BLACKLIST.include? partner
        
        "#{klass} -- #{partner} : > #{relation}"
      end.reject(&:nil?).sort.each{|e| puts e}
    end  
  end
end

Main.run
