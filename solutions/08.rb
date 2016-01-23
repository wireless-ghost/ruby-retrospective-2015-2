require 'pp'

class ColumnGenerator

  def initialize(count)
    @columns = []
    @count = count
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

  def int?
    @real_value.match(/^\d+$/) != nil
  end

  def get_int
    @real_value.to_i
  end

  def to_s
    mask = '%p'
    if @real_value.is_a? Numeric
      @real_value = @real_value.to_f
      mask = if @real_value % 1 == 0 then '%d' else '%.2f' end
    end
    sprintf(mask, @real_value)
  end

end

class Formula

  attr_reader :result

  def initialize(string, values)
    @result = -1
    check_brackets(string)
    function_name = string[1..string.length].split(/\(/).first
    eval "#{function_name.downcase}(#{values})"
  end

  def check_brackets(string)
    open = string.index('(')
    close = string.index(')')
    if ! open || ! close || open > close
      raise Spreadsheet::Error, "Invalid expression #{string}"
    end
  end

  def get_messages(name, arguments)
    @less = "Wrong number of arguments for 'FN': expected at least 2, got ARG"
    @more = "Wrong number of arguments for 'FN': expected 2, got ARG"
    less = @less.gsub("ARG", arguments.to_s).gsub("FN", name)
    more = @more.gsub("ARG", arguments.to_s).gsub("FN", name)
    [less, more]
  end

  def add(values)
    if (values.count < 2)
      raise Spreadsheet::Error, get_messages("ADD", values.count)[0]
    end
    @result = values.inject(:+).to_f
  end

  def multiply(values)
    if (values.count < 2)
      raise Spreadsheet::Error, get_messages("MULTIPLY", values.count)[0]
    end
    @result = values.inject(:*).to_f
  end

  def subtract(values)
    if (values.count < 2)
      raise Spreadsheet::Error, get_messages("SUBTRACT", values.count)[0]
    elsif (values.count > 2)
      raise Spreadsheet::Error, get_messages("SUBTRACT", values.count)[1]
    end
    @result = (values[0] - values[1]).to_f
  end

  def divide(values)
    if (values.count < 2)
      raise Spreadsheet::Error, get_messages("DIVIDE", values.count)[0]
    elsif (values.count > 2)
      raise Spreadsheet::Error, get_messages("DIVIDE", values.count)[1]
    end
    @result = (values[0] / values[1]).to_f
  end

  def mod(values)
    if (values.count < 2)
      raise Spreadsheet::Error, get_messages("MOD", values.count)[0]
    elsif (values.count > 2)
      raise Spreadsheet::Error, get_messages("MOD", values.count)[1]
    end
    @result = (values[0] % values[1]).to_f
  end
end

class Spreadsheet

  class Error < StandardError
  end

  attr_accessor :table, :rows, :columns

  def initialize(table = '')
    @row_count, @column_count = 1, -1
    @columns, @table = [], Hash.new
    generator = ColumnGenerator.new((table.lines.first || '').split(' ').count)
    @columns = generator.get_columns
    @row_count , @column_count = 1, 0
    populate_cells(table)
  end

  def populate_cells(table)
    table.lines.each do |row|
      @column_count = 0
      row.split(' ').each do |cell|
        add_cell(cell)
        @column_count += 1
      end
      @row_count += 1
    end
  end

  def check_table(value)
    res = value
    if value.match(/^\d+$/) == nil && cell_at(value)
      res = @table[value].get_int
    end
    res.to_i
  end

  def add_cell(value)
    real = value
    if (value.start_with?("="))
      split_values = value[/\((.*?)\)/, 1].split(',').map{ |s| check_table(s) }
      real = Formula.new(value, split_values).result
    end
    @table["#{@columns[@column_count]}#{@row_count}"] = Cell.new(value, real)
  end

  def to_s
    result, row = "", 1
    print(result, row)
    result
  end

  def print(result, row)
    @table.each do |key, value|
      if (/^*\d+$/.match(key).to_s.to_i == row)
        result << value.to_s + "\t"
      else
        result << "\n#{value.to_s}\t"
        row = /^*\d+$/.match(key).to_s.to_i
      end
    end
  end

  def cell_at(cell_index)
    if ! @table.has_key? (cell_index)
      raise Error, "Invalid cell index '#{cell_index}'"
    else
      @table[cell_index].text_value
    end
  end

  def [](cell_index)
    if ! @table.has_key? (cell_index)
      raise Error, "Invalid cell index '#{cell_index}'"
    else
      @table[cell_index].real_value
    end
  end
end
