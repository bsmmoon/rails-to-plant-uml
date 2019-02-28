=begin
  TODO
  1. If line ends with ",", it should be merged with the previous line
  2. If there is a "class_name" token, partner should be the string that comes after
  3. If multiple files are given, remove belongs_to that is not required
=end

require 'active_support/inflector'

class Main
  def self.run
    Main.new.run(Main.data(ARGV[0]).split("\n"))
  end

  BLACKLIST = Set.new %w'ActiveSupportConcern'

  def run(lines)
    klass = ''
    lines.map do |line|
      tokens = line.strip.split(' ')
      case relation = tokens.shift
      when 'class'
        klass = "#{klass}#{tokens.shift}"
        klass.slice!('::')
        next
      when 'module'
        klass = "#{klass}#{tokens.shift}"
        klass.slice!('::')
        next
      when 'belongs_to'
        partner = tokens.shift
      when 'has_many'
        partner = tokens.shift.singularize
      when 'has_one'
        partner = tokens.shift
      when 'include'
        partner = tokens.shift
      when 'extend'
        partner = tokens.shift
      else
        next
      end
      partner = partner[1...partner.length] if partner[0] == ':'
      partner = partner[0...partner.length-1] if partner[partner.length - 1] == ','
      partner.slice!('::')
      partner = partner.camelize
      next if BLACKLIST.include? partner
      "#{partner} : > #{relation}"
    end.reject(&:nil?).map{|rel| "#{klass} -- #{rel}"}.sort.each{|e| puts e}
  end

  def self.data(filename)
    file = File.open(filename, "r")
    data = file.read
    file.close
    data  
  end
end

Main.run
