module TurtleGraphics
  module Canvas
    class Helper
      def self.populate_canvas(width, height, canvas, max)
        (0..(height - 1)).each do
          row = []
          (1..width).each do
            row.push(0)
          end
          canvas.push(row)
        end
        canvas[0][0] = 1
        max = 1
      end
    end

    class Standard
      ORIENTATIONS = %i(right down left up)
      attr_accessor :width, :height, :x, :y, :canvas, :max

      def initialize(width, height)
        @width, @height = width, height
        @canvas = []
        @max = 0
        if width != 0 && height != 0
          Helper.populate_canvas(@width, @height, @canvas, @max)
        end
        @row, @column = 0, 0
        @orientation = 0
      end

      def draw(&block)
        self.instance_eval(&block)
        @canvas
      end

      def turn_right
        @orientation += 1
        @orientation = 0 if @orientation > 3
      end

      def turn_left
        @orientation -= 1
        @orientation = 3 if @orientation < 0
      end

      def fix_position
        @column = 0 if @column == @width
        @column = @width - 1 if @column < 0
        @row = 0 if @row == @height
        @row = @height - 1 if @row < 0
        @canvas[@row][@column] += 1
        @max = @canvas.flatten.max if @canvas[@row][@column] > @max
      end

      def move
        if ORIENTATIONS[@orientation] == :right
          @column += 1
        elsif ORIENTATIONS[@orientation] == :down
          @row += 1
        elsif ORIENTATIONS[@orientation] == :left
          @column -= 1
        elsif
          @row -= 1
        end
        fix_position
      end

      def spawn_at(row, column)
        @canvas[0][0] = 0
        @canvas[row][column] = 1
        @row, @column = row, column
        @orientation = 0
      end

      def look(orientation)
        @orientation = ORIENTATIONS.index(orientation)
      end
    end

    class ASCII < Standard
      def initialize(chars)
        @chars = chars
        super(0,0)
      end

      def draw(&block)
        self.instance_eval(&block)
        to_s
      end

      def get_symbol(intensity)
        step = 1.0 / (@chars.size - 1)
        index, initial_intensity = 0, 0
        while intensity > initial_intensity
          index += 1
          initial_intensity += step
        end
        @chars[index]
      end

      def add_column(element)
        get_symbol(element.to_f / @max)
      end

      def add_row(row)
        result = ""
        row.each do |element|
          result += add_column(element)
        end
        result + "\n"
      end

      def to_s
        result = ""
        @canvas.each do |row|
          result += add_row(row)
        end
        result.chomp
      end
    end

    class HTML < Standard
      HTML_STRING = "
<!DOCTYPE html>
<html>
  <head>
    <title>Turtle graphics</title>
    <style>
      table {
        border-spacing: 0;
      }

      tr {
        padding: 0;
      }

      td {
        width: ##|width|##px;
        height: ##|height|##px;

        background-color: black;
        padding: 0;
      }
    </style>
    </head>
    <body>
      <table>
      ##|table|##
      </table>
    </body>
</html>"

      def initialize(pixels)
        @pixels = pixels
        super(0,0)
      end

      def draw(&block)
        self.instance_eval(&block)
        to_s
      end

      def generate_td(element)
        "<td style=\"opacity: #{format('%.2f', (element.to_f / @max)) }\" ></td>"
      end

      def generate_tr(row)
        result = '<tr>'
        row.each do |element|
          result << generate_td(element)
        end
        result << '</tr>'
        result
      end

      def to_s
        table = ""
        @canvas.each do |row|
          table << generate_tr(row)
        end
        result = HTML_STRING.gsub("##|table|##", table)
        result = result.gsub!("##|width|##", @pixels.to_s)
        result = result.gsub!("##|height|##", @pixels.to_s)
        result
      end
    end
  end

  class Turtle
    def initialize(height, width)
      @width, @height = width, height
      @canvas = Canvas::Standard.new(width, height)
    end

    def draw(canvas = nil, &block)
      if canvas != nil
        canvas.width = @width
        canvas.height = @height
        Canvas::Helper.populate_canvas(@width, @height, canvas.canvas, canvas.max)
        canvas.draw(&block)
      else
        @canvas.draw(&block)
      end
    end
  end
end
