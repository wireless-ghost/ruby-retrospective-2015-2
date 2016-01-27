require 'pp'

class Helper
  def self.check_string_for_numeric(value)
    value.match(/\d+.\d+/) || value.match(/^\d+$/)
  end

  def self.pattern
    /\s{2,}|\t/
  end

  def self.check_brackets(string)
    open = string.index('(')
    close = string.index(')')
    if ! open || ! close || open > close
      raise Spreadsheet::Error, "Invalid expression '#{string[1..-1]}'"
    end
    string
  end
end

class ColumnGenerator
  def initialize(row)
    count = row.split(Helper.pattern).count
    @columns = []
    @count = count
    @column_count = -1
    generate_columns('', @count)
  end

  def get_columns
    @columns
  end

  private

  def generate_letters(char, count)
    @columns << (65..(90 - 26 + count)).map(&:chr).map { |x| x = "#{char}#{x}"}
    @columns.flatten!
  end

  def generate_columns(char, count)
    if (count >= 26)
      generate_letters(char, 26)
      generate_columns(@columns[@column_count += 1], count - 26)
    else
      generate_letters(char, count)
    end
  end
end

class Cell
  attr_accessor :text_value, :real_value

  def initialize(text_value, real_value)
    @text_value, @real_value = text_value, real_value
  end

  def cell_int?
    is_float = !!Float(@text_value) rescue false
    is_float && (@real_value.is_a? Numeric)
  end

  def get_int
    @real_value.to_f
  end

  def to_s
    if cell_int? || @text_value.start_with?("=")
      integer, float = @real_value.to_i, @real_value.to_f
      integer == float ? integer.to_s : "%.2f" % @real_value
    else
      @text_value
    end
  end
end

class Formula
  VALID_FORMULAS = ["ADD", "SUBTRACT", "MULTIPLY", "MOD", "DIVIDE"]

  attr_reader :result

  def initialize(string, values)
    @result = -1
    Helper.check_brackets(string)
    function_name = string[1..string.length].split(/\(/).first
    if ! VALID_FORMULAS.include? function_name
      raise Spreadsheet::Error, "Unknown function '#{function_name}'"
    end
    eval "#{function_name.downcase}(#{values})"
  end

  def get_messages(name, arguments)
    @less = "Wrong number of arguments for 'FN': expected at least 2, got ARG"
    @more = "Wrong number of arguments for 'FN': expected 2, got ARG"
    less = @less.gsub("ARG", arguments.to_s).gsub("FN", name)
    more = @more.gsub("ARG", arguments.to_s).gsub("FN", name)
    [less, more]
  end

  def add(values)
    if values.count < 2
      raise Spreadsheet::Error, get_messages("ADD", values.count)[0]
    end
    @result = values.inject(:+).to_f
  end

  def multiply(values)
    if values.count < 2
      raise Spreadsheet::Error, get_messages("MULTIPLY", values.count)[0]
    end
    @result = values.inject(:*).to_f
  end

  def subtract(values)
    if values.count != 2
      raise Spreadsheet::Error, get_messages("SUBTRACT", values.count)[1]
    end
    @result = (values[0] - values[1]).to_f
  end

  def divide(values)
     if values.count != 2
       raise Spreadsheet::Error, get_messages("DIVIDE", values.count)[1]
    end
    @result = (values[0] / values[1]).to_f
  end

  def mod(values)
    if values.count != 2
      raise Spreadsheet::Error, get_messages("MOD", values.count)[1]
    end
    @result = (values[0] % values[1]).to_f
  end
end

class TablePrinter
  def print(result, row, table)
    table.each do |key, value|
      next if key == "A1"
      if (/^*\d+$/.match(key).to_s.to_i == row)
        result << "\t" + value.to_s
      else
        result << "\n" + value.to_s
        row = /^*\d+$/.match(key).to_s.to_i
      end
    end
  end
end

class Spreadsheet
  class Error < StandardError
  end

  attr_accessor :table, :rows, :columns

  def initialize(table = '')
    @row_count, @column_count = 1, 0
    @columns, @table = [], {}
    generator = ColumnGenerator.new((table.lines.first || ''))
    @columns = generator.get_columns
    populate_cells(table)
    @table.each { |key, cell| cell.real_value = evaluate_cell(cell.real_value) }
  end

  def populate_cells(table)
    table.lines.each do |row|
      @column_count = 0
      row.strip.split(Helper.pattern).each do |cell|
        @table["#{@columns[@column_count]}#{@row_count}"] = Cell.new(cell, cell)
        @column_count += 1
      end
      @row_count += 1
    end
  end

  def check_table(value)
    res = value
    if ! Helper.check_string_for_numeric(value) && cell_at(value)
      res = @table[value].get_int
    end
    res.to_f
  end

  def evaluate_cell(value)
    real = value
    if value.start_with?("=") && Helper.check_brackets(value)
      temp = value.gsub(/\s+/, "")
      split_values = temp[/\((.*?)\)/, 1].split(',').map{ |s| check_table(s) }
      real = Formula.new(temp, split_values).result
    end
    real
  end

  def to_s
    result, row = '', 1
    result << @table["A1"].to_s unless @row_count == 0
    TablePrinter.new.print(result, row, @table) unless @row_count == 0
    result
  end

  def cell_at(cell_index)
    if not @table.has_key? (cell_index)
      raise Error, "Cell '#{cell_index}' does not exist"
    else
      @table[cell_index].text_value
    end
  end

  def [](cell_index)
    if not @table.has_key? (cell_index)
      raise Error, "Cell '#{cell_index}' does not exist"
    else
      @table[cell_index].to_s
    end
  end

  def empty?
    @columns.count == 0
  end
end
