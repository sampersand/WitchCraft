require_relative 'sub'


class Klass
  attr_accessor :public, :static, :name, :generics, :fields, :subs

  def initialize
    @generics = []
    @fields = {}
    @subs = {}
  end
end

KEYWORDS = %w[
  public static klass enter sub leave return
]

def parse_klasses! code
  $klasses ||= {}
  stage = 0
  indentation = nil
  while begin
    nil while code.delete_prefix! "\n" # delete leading newlines on their own
    while code.slice! /\A\s+/ or code.slice! /\A%.*\n/ 
    end
    
    # if indentation
    #   $&.start_with? indentatino
    #   $current_klass = nil
    #   stage = 0
    #   next
    # end

    unless parsed = code.slice!(/\A(\w+\b|[-+*\/&|,;=:\(\)\{\}\[\]])/)
      break if stage == 0 || stage == 10
    end
    true
  end do
    (stage = 0; $current_klass = nil; next) if parsed == 'EOK'

    is_ident = parsed =~ /\A[_a-zA-Z]\w*\Z/ && !KEYWORDS.include?(parsed.downcase)

    # p [stage, parsed]
    case [(stage += 1) - 1, parsed]
    # klass construction
    in 0, /public/i then ($current_klass ||= Klass.new).public = true
    in 0 | 1, /static/i then ($current_klass ||= Klass.new).static = true; stage = 2
    in 0 | 1 | 2, /klass/i then stage = 3
    in 0 | 1 | 2, _ then raise "expected klass"
    in 3, _ if is_ident then $klasses[($current_klass ||= Klass.new).name = parsed] = $current_klass
    in 3, _ then raise "expected identifier for klass"
    in 4, '[' then # do nothing, go to stage 5
    in 5 | 6, ']' then stage = 7
    in 5, _ if is_ident then $current_klass.generics << parsed
    in 5, _ then raise "expected identifier for generic name"
    in 6, ',' then stage = 5
    in 6, _ then raise "expected `,` or `]`"
    in 4 | 7, ':' then stage = 10
    in 4 | 7, _ then raise "expected `:` after a klass"

    # field parsing
    in 10, /public/i then ($current_field ||= {})[:public] = true
    in 10 | 11, /static/i then ($current_field ||= {})[:static] = true; stage = 12
    in 10 | 11 | 12, _ unless is_ident || parsed == '*' then
      raise "unexpected `public` or `static`" if $current_field
      stage = 19
      redo
    in 10 | 11 | 12, _
      (($current_field ||= {})[:type] ||= '').concat parsed
      stage = parsed == '*' ? 12 : 13
    in 13, _ if is_ident then $current_klass.fields[$current_field[:name] = parsed] = $current_field
    in 13, _ then raise "expected ident for field name"
    in 14, '=' then stage = 15
    in 14, ';' then stage = 10; $current_field = nil
    in 14, _ then raise "expected `=` or `;` after static"
    in 15, _
      $current_field[:init] = parsed + code.slice!(/\A(.*?);/m)[..-2]
      $current_field = nil
      stage = 10

    # sub creation
    in 19, /enter/i then
    in 19, _ then raise raise "expected `*`, an ident, or `enter`"
    in 20, /sub/i then
    in 20, _ then raise "expected `sub` after `enter"
    in 21, /public/i then ($current_sub ||= Sub.new).public = true
    in 22, /static/i then ($current_sub ||= Sub.new).static = true
    in 21 | 22 | 23, _ unless is_ident then raise "expected type sub name, got #{parsed.inspect}"
    in 21 | 22 | 23, _ then $current_klass.subs[($current_sub ||= Sub.new).name = parsed] = $current_sub; stage = 24
    in 24, '[' then stage = 24.1

    in 4, '[' then # do nothing, go to stage 5
    in 5 | 6, ']' then stage = 7
    in 5, _ if is_ident then $current_klass.generics << parsed
    in 5, _ then raise "expected identifier for generic name"
    in 6, ',' then stage = 5
    in 6, _ then raise "expected `,` or `]`"
    in 4 | 7, ':' then stage = 10


    in 24, '(' then
    in 24, _ then raise 'expected `(` after sub name'
    in 25, ')' | '-' then stage = 28; redo
    in 25, _ unless is_ident then raise "expected variable name, `-->` or `)`, not #{parsed.inspect}"
    in 25, _ then $current_sub.args << ($current_arg = {type: ''})[:name] = parsed
    in 26, ':' then
    in 26, _ then raise "expected `:` after variable name (not #{parsed.inspect})"
    in 27, '*' then $current_arg[:type].concat '*'; stage = 27
    in 27, _ if is_ident then $current_arg[:type].concat parsed
    in 27, _ then raise "expected `*` or an ident, not #{parsed.inspect}"
    in 28, ',' then stage = 25
    in 28, ')' then stage = 30
    in 28, '-' if code.slice!(/\A-+>/) then $current_sub.return_type = ''
    in 28, _ then raise "expected `,`, `-->`, or somethin else idk, not #{parsed.inspect}"
    in 29, '*' then $current_sub.return_type.concat '*'; stage -= 1
    in 29, _ if is_ident then $current_sub.return_type.concat parsed
    in 29, _ then raise "expected `*` or an ident, not #{parsed.inspect}"
    in 30, _
      unless code.slice!(/\A(.*?)\bleave\s+sub\s+#{$current_sub.name}/mi)
        raise "expected `leave sub #{$current_sub.name}` at some point"
      end
      $current_sub.body = $1
      $current_sub = nil
      stage = 10

    # otherwise it's an error
    else raise "unknown token #{parsed.inspect} at stage #{stage}"
    end
  end
end
