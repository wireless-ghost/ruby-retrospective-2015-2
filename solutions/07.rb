require 'pp'

module LazyMode

  class Date

    attr_accessor :day, :month, :year

    def initialize(date_string)
      @year, @month, @day = * date_string.split('-').map(&:to_i)
    end

    def to_s
      "#{ "%04d" % @year }-#{ "%02d" % @month }-#{ "%02d" % @day }"
    end

    def add_days(count)
      if (@day + count > 30)
        add_months(1)
        @day += count - 30
      else
        @day += count
      end
      self
    end

    def add_weeks(count)
      add_days(7 * count)
      self
    end

    def add_months(count)
      if ( @month + count > 12 )
        add_years(1)
        @month += count - 12
      else
        @month += count
      end
      self
    end

    def add_years(count)
      @year += count
      self
    end

    def ==(other)
      @year == other.year && @month == other.month && @day == other.day
    end

    def <=>(other)
      [@year, @month, @day] <=> [other.year, other.month, other.day]
    end

  end

  def self.create_file(file_name, &block)
    file = File.new(file_name)
    file.instance_eval(&block)
    file
  end

  class DailyAgenda

    def initialize(file, date)
      @file, @date = file, date
      if @file.notes != nil
        filter_notes
      end
    end

    def filter_notes
      @file.notes.each { |note| note.scheduled @date.to_s }
    end

    def where(*parameters)
      FilteredNotes.new(@file.dup, parameters)
    end

    def notes
      @file.notes
    end
  end

  class WeeklyAgenda

    def initialize(file, date)
      @file = file
      @date = date

      @file.notes = loop_days
    end

    def loop_days
      result = []
      #pp "LOOP"
      #pp @file.notes.size
      (0.upto(6)).each do |day|
        #pp "RESULT FOR #{day} IS #{result.count}"
        result << collect_weekly_notes(day)
      end
      result.flatten
    end

    def collect_weekly_notes(day)
      result = []
      @file.notes.each do |note|
        result = get_note_for_day(result, note, day)
      end
      #pp "FINAL RES: #{result.flatten.count}"
      result.flatten
    end

    def validate_note(note, date)
      #pp date, "BATATTA"
      if note.valid?(date)
        #pp note.header, date
        new_note = note.dup
        #pp @file.notes.size
        new_note.period = [date]
        new_note
      else
        nil
      end
    end

    def get_note_for_day(result, note, day)
      new_note = validate_note(note, @date.dup.add_days(day))
      #pp new_note
      result << new_note if new_note
      result.flatten
    end

    def notes
      @file.notes
    end

    def where(*parameters)
      FilteredNotes.new(@file.dup, parameters)
    end
  end

  class FilteredNotes

    def initialize(file, parameters)
      @file = file.dup
      filter_by_text(parameters[0][:text])
      filter_by_status(parameters[0][:status])
      filter_by_tag(parameters[0][:tag])
    end

    def filter_by_tag(tag)
      result = []
      if tag
        collect_tags(tag)
      end
      result.flatten
    end

    def collect_tags(tag)
      @file.notes = @file.notes.select { |note| note.tags.include? tag }
    end

    def filter_by_status(status)
      result = []
      if status
        result << collect_status(status)
      end
      result.flatten
    end

    def collect_status(status)
      @file.notes = @file.notes.select { |note| note.status == status }
    end

    def notes
      @file.notes
    end

    def filter_by_text(text)
      result = []
      if text
        result << collect_text(text)
      end
      result.flatten
    end

    def collect_text(text)
      result = []
      result << @file.notes.select { |note| note.body =~ text }
      result << @file.notes.select { |note| note.header =~ text }
      @file.notes = result.flatten.uniq
    end
  end

  class File

    attr_accessor :name, :notes

    def initialize(file_name)
      @name = file_name
      @notes = []
    end

    def daily_agenda(date)
      file = self.dup
      file.notes.select! { |note| note.valid?(date) }
      DailyAgenda.new(file, date)
    end

    def weekly_agenda(date)
      WeeklyAgenda.new(self.dup, date)
    end

    def note(header, *tags, &block)
      note = Note.new(header, tags, self)
      note.file_name = @name
      note.instance_eval(&block)
      @notes << note
    end

    def add_note(note)
      @notes << note
    end

    def where(*parameters)
      FilteredNotes.new(self, parameters)
    end

  end

  class Note

    attr_accessor :header, :file_name, :body, :status, :tags, :children, :period

    def initialize(header, tags, file)
      @tags = tags
      @header = header
      @status = :topostpone
      @file = file
      @period = []
    end

    def note(header, *tags, &block)
      note = Note.new(header, tags, @file)
      note.instance_eval(&block)
      @file.add_note(note)
    end

    def status(value = nil)
      @status = value if value
      @status
    end

    def body(value = '')
      @body = value if value != ''
      @body || ''
    end

    def scheduled(date_string)
      @period, split_date = [], date_string.split(' ')
      start_date = LazyMode::Date.new(split_date.first)

      @period << start_date
      repeat = split_date.last[-1]
      duration = split_date.last[1..-1].split(/\D+/).first
      100.downto 1 do repeat_by(repeat, @period.last, duration.to_i) end
    end

    def repeat_by(repeat, start_date, duration)
      @period << (start_date.dup.add_weeks (duration)) if repeat == 'w'
      @period << (start_date.dup.add_months (duration)) if repeat == 'm'
      @period << (start_date.dup.add_days (duration)) if repeat == 'd'
      @period.reverse
    end

    def valid?(date)
      @period.include?(date) ? date : nil
    end

    def date
      @period.first
    end
  end

end
=begin
file = LazyMode.create_file('file') do
  note 'simple note' do
    scheduled '2012-11-12 +2m'
  end

  note 'simple note 2' do
    scheduled '2012-12-13 +2m'
  end
end

agenda = file.weekly_agenda(LazyMode::Date.new('2013-01-10'))
pp "JOKER"
pp agenda.notes
pp agenda.notes.size
=begin
file = LazyMode.create_file('file') do
  note 'simple note' do
    scheduled '2012-12-12'
  end

  note 'simple note 2' do
    scheduled '2012-12-13'
  end
end

agenda = file.daily_agenda(LazyMode::Date.new('2012-12-12'))
#pp agenda.notes.size
=begin
file = LazyMode.create_file('not_important') do
  note 'not_important' do
    body 'Do not forget to...'
   end
end

pp file.notes.first.body
=end
