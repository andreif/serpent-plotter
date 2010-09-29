#!/usr/bin/env ruby

=begin TODO:
1. command history - read by character
2. defaults in serpent-plotter.yaml
=end

raise "Plotter requires Ruby 1.9.x! See rvm.beginrescueend.com" unless RUBY_VERSION =~ /^1\.9/

class SerpentPlotter
  
  FILE_DEFAULTS = 'serpent-plotter.yaml'
  FILE_LOG      = 'serpent-plotter.log'
  FILE_TEMP     = 'serpent-plotter.input'
  SERPENT_EXEC  = 'sss'
  IMAGE_VIEWER  = 'open -ga Preview %s'
  
  def initialize
    self.print_title
    self.load_defaults
    self.check_input
    self.print_status
    self.load_keywords
    loop do
      commands = self.parse_command self.get_command
      commands.each do |cmd|
        self.process_command cmd
      end
      self.plot
      self.print_status unless commands.empty?
    end
  end
  
  
  def load_keywords
    @keywords = {}
    COMMANDS.strip.split("\n").collect do |line|
      coms,help = line.strip.split('=',2)
      coms = coms.downcase.split.collect {|c|c.to_sym}
      @keywords[coms.first] = coms
    end
  end
  
  def check_input
    raise "File not found" unless File.exists? @input
  end
  
  
  def load_defaults
    # set basic defaults
    @input = ARGV.first
    @resolution = self.set_defaults([600,600,300], 6)
    @extent     = self.set_defaults([100.0], 6)
    @origin = 0,0,0
    @axis = :z
    @previous_command = nil
    @three = false
    # load defaults from yaml file
  end
  
  
  def get_command
    Kernel.print "\x1b[32m>>\x1b[0m "
    while (s = STDIN.gets.strip).empty?
      Kernel.print "\x1b[32m>>\x1b[0m "
    end
    return s
  end
  
  
  
  def parse_command str
    result = [[]]
    str.split.each_with_index do |word,i|
      if self.is_keyword? word
        result << [word.downcase.to_sym]
      else
        unless result.last.empty?
          result.last << word 
        else
          self.show_error unknown: word
        end
      end 
    end
    result.shift if result.first.empty?
    return result
  end
  
  
  def show_error msg
    case msg
      when Hash
        case msg.keys.first
          when :unknown
            self.show_error("Unknown command '%s'. Type 'help' to list available commands." % msg.values.first)
        else raise end
    else
      Kernel.puts self.colorize(31, ' Error: ' + msg.strip)
    end
  end
  
  
  def is_keyword? str
    @keywords.values.flatten.include? str.downcase.to_sym
  end
  
  def process_command cmd
    return unless self.valid_command? cmd
    values = cmd.dup
    case keyword = values.shift
      when :plot
      when :exit then Kernel.exit
      when :help then self.print_help
      when :repeat,:r then return self.process_command @previous_command
      when :px,:py,:pz
        @axis = keyword[-1].to_sym
        @origin[ self.xyz ] = values.first.to_f unless values.empty?
      when :origin,:or,:o then @origin = self.numeric values
      when :center, :c then @origin = 0.0, 0.0, 0.0
      when :reset, :rs then @origin = 0.0, 0.0, 0.0; @extent = self.set_defaults([100.0], 6)
      when :zoomin,:zi  then @extent.collect! {|e| e / (values.first || 2).to_f }
      when :zoomout,:zo then @extent.collect! {|e| e * (values.first || 2).to_f }
      when :lowres,:lres,:lr  then @resolution.collect! {|e| (e / (values.first || 2).to_f).to_i }
      when :highres,:hres,:hr then @resolution.collect! {|e| (e * (values.first || 2).to_f).to_i }
      when :ex,:extent then @extent = self.set_defaults( self.numeric(values), 6 )
      when :res    then @resolution = self.set_defaults( self.numeric(values), 6, 0.5 ).collect{|f|f.to_i}
      when :one,:three then @three = keyword == :three
      when *@keywords[:moveup]    then @origin[ self.xyz(self.axis(1,2)) ] += (values.first || @extent[1]/1.0).to_f
      when *@keywords[:movedown]  then @origin[ self.xyz(self.axis(1,2)) ] -= (values.first || @extent[1]/1.0).to_f
      when *@keywords[:moveright] then @origin[ self.xyz(self.axis(1,1)) ] += (values.first || @extent[0]/1.0).to_f
      when *@keywords[:moveleft]  then @origin[ self.xyz(self.axis(1,1)) ] -= (values.first || @extent[0]/1.0).to_f
      when *@keywords[:movein]    then @origin[ self.xyz(@axis) ] -= values.first.to_f
      when *@keywords[:moveout]   then @origin[ self.xyz(@axis) ] += values.first.to_f
    else
      self.show_error unknown: keyword
    end
    #self.plot unless [:help].include? keyword
    @previous_command = cmd
  end
  
  def set_defaults var, n=6, fr=1
    '1 0   2 0  3 2   4 2  5 3'.split.each_slice(2) do |a|
      var[a.first.to_i] ||= var[a.last.to_i] * (a.first == '2' ? fr.to_f : 1)
    end
    return var
  end
  
  
  def xyz *args # x,y,z,axis=nil
    case args.count
      when 3,4 then x,y,z,axis = args
      when 1 then axis = args.first
    end
    x ||= 0; y ||= 1; z ||= 2; axis ||= @axis
    return {x:x,y:y,z:z}[ axis ]
  end
  
  
  def view axis_or_axes=nil
    axis_or_axes ||= @axis
    case @axis
      when :x then {x:1,yz:1, y:2,xz:2, z:3,xy:3}[axis_or_axes]
      when :y then {x:3,yz:3, y:1,xz:1, z:2,xy:2}[axis_or_axes]
      when :z then {x:2,yz:2, y:3,xz:3, z:1,xy:1}[axis_or_axes]
    else raise end
  end
  
  
  def axis view=1, axis_nr=nil
    case @axis
      when :x then a=[:x,:y,:z][view-1]
      when :y then a=[:y,:x,:z][view-1]
      when :z then a=[:z,:x,:y][view-1]
    else raise end
    if axis_nr
      a = self.axes(a)[axis_nr-1].to_sym
    end
    return a
  end
  
  
  def axes axis_or_view=nil
    case axis_or_view
      when Fixnum then axis = self.axis(view = axis_or_view)
      when Symbol then axis = axis_or_view
      when Nil then axis = @axis
    else raise end
    return {x: :yz, y: :xz, z: :xy}[axis]
  end
  
  
  def valid_command? cmd
    true # not implemented
  end
  
  
  def numeric *args
    args.flatten.collect{|s|s.to_f}
  end
  
  
  def print_help
    Kernel.puts COMMANDS
  end
  
  
  def plot
    self.check_input
    self.prepare_input
    # run serpent -plot
    Kernel.system '%s %s > %s' % [SERPENT_EXEC, FILE_TEMP, FILE_LOG]
    self.display_errors
    Kernel.system IMAGE_VIEWER % (FILE_TEMP + '_geom1.png')
    if @three
      Kernel.system IMAGE_VIEWER % (FILE_TEMP + '_geom2.png')
      Kernel.system IMAGE_VIEWER % (FILE_TEMP + '_geom3.png')
    end
    # clean input and png
  end
  
  #(0..20).each {|j| (0..110).each {|i| print "\x1b[%d;%dmA\x1b[0m" % [j,i] };puts"\n"}
  def display_errors
    log = IO.read FILE_LOG
    log,no = log.split 'Reading directory files'
    i = log.index(/\n[^\n]+error/)
    Kernel.puts "\x1b[31m" + log[i..log.length] + "\x1b[0m" if i
  end
  
  
  def prepare_input
    text = IO.read @input
    # remove set acelib
    text.gsub! /(^|\s+)\s*set\s+acelib\s+[^\n]+\n/i, "\n"
    # remove other plot commands
    text.gsub! /(^|\s+)\s*plot\s+[^\n]+\n/i, "\n"
    # add plot command # plot 1 2000 2000 5 -48 48 -48 48
    text += "\n" + self.plot_card(@axis, 1)
    if @three
      text += "\n" + self.plot_card( self.xyz(:y,:x,:x), 2 )
      text += "\n" + self.plot_card( self.xyz(:z,:z,:y), 3 )
    end
    File.open(FILE_TEMP, 'w+') do |f|
      f.write(text)
    end
  end
  
  
  
  
  
  def plot_card axis, start
    #start = {x:0,y:2,z:4}[axis]
    resolution = @resolution[(start-1)*2,2]
    extent     = @extent[(start-1)*2,2]
    "plot %s   %d %d   %s   %s %s   %s %s " % [ 
      {x:1,y:2,z:3}[axis],
      resolution.first,
      resolution.last,
      @origin[ {x:0,y:1,z:2}[axis] ],
      @origin[ {x:1,y:0,z:0}[axis] ] - extent.first,
      @origin[ {x:1,y:0,z:0}[axis] ] + extent.first,
      @origin[ {x:2,y:2,z:1}[axis] ] - extent.last,
      @origin[ {x:2,y:2,z:1}[axis] ] + extent.last
    ]
  end
  
  
  def colorize color, var
    if var.class == Array
      return var.collect {|el| self.colorize(color,el) }
    else
      return "\x1b[#{color}m#{var.to_s}\x1b[0m"
    end
  end
  
  
  def print_status
    Kernel.print "\norigin \x1b[32m%d %d %d\x1b[0m  extent \x1b[32m%d %d\x1b[0m  " % (@origin + @extent[0,2])
    Kernel.puts "basis \x1b[32m%s\x1b[0m" % {x:'0 1 0  0 0 1', y:'1 0 0  0 0 1', z:'1 0 0  0 1 0'}[@axis]
    (1..(@three ? 3 : 1)).each do |view|
      axes = self.axes(view)
      a,b = axes[0].to_sym, axes[1].to_sym
      ia,ib = self.xyz(a), self.xyz(b)
      Kernel.puts "view %s: axes %s(%s,%s) %s(%s,%s) resolution %s x %s" % [
        self.colorize(32, view),
        a.to_s.upcase,
        self.colorize(35, @origin[ia] - @extent[(view-1)*2]),
        self.colorize(35, @origin[ia] + @extent[(view-1)*2]),
        b.to_s.upcase,
        self.colorize(35, @origin[ib] - @extent[(view-1)*2+1]),
        self.colorize(35, @origin[ib] + @extent[(view-1)*2+1]),
       *self.colorize(32, @resolution[(view-1)*2, 2])
      ]
    end
    Kernel.puts "\n"
  end
  
  
  def print_title
    Kernel.puts "\n  Interactive Plotter for Serpent - August 21, 2010 \n\nType 'exit' to close, or 'help' for all available commands"
  end
  
  COMMANDS = '
  help           = shows this information
  exit           = exits the plotter
  px py pz       = [N] changes axis of view, takes optional argument - position on the axis
  origin or o    = N N N sets coordinates of view-point
  center c       = equivalent to "origin 0 0 0"
  extent ex      = N1 [N2=N1] [M1=N1] [M2=N2] [M3=M1] [M4=M2] sets extents for both axes of the current coordinate plane
  resolution res = N1 [N2=N1] [M1=N1] [M2=N2] [M3=M1] [M4=M2] changes images resolution
  plot           = plots or refreshs current view
  one three      = sets number of active views
  reset rs       = resets view to default
  repeat r       = repeat the last command
  moveup mu up u = [N=ext/2] moves current view, by default for the half of screen
  movedown md down d =
  moveleft ml left l =
  moveright mr right rt =
  movein mi in = N - moves view in or out
  moveout mo out = 
  zoomin zi = [N=2] changes extent by a factor N
  zoomout zo =
  prev next      = changes view back-forward
  save           = [N=1] save view
  rotate rot     = [W=left|right|up|down] rotates view relative to 0 0 0
  setx sx sety sy setz sz = N1 N2 sets range for axes
  color col      = MAT HEX set color for material
  recolorize rc  = rest colors to certain order
  view v         = [N=2] change view to other
  highres hres hr lowres lres lr = [N=2] change resolution N times
  '
end


SerpentPlotter.new




