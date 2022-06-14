require_relative 'container'
require_relative 'value'
require 'fiddle'

class Value
  def initialize(kind=nil, data=nil)
    @kind = nil
    @data = nil
  end

  def kind= kind
    raise "kind already set" if @kind
    @kind = kind
  end

  def data= data
    @data = data
    @kind ||= data.kind
  end
end

class Arg
  attr_accessor :type, :name
  def initialize
    @type = Type.new
  end
end

class Type
  attr_accessor :pointer_depth, :name
  def initialize
    @pointer_depth = 0
  end
end


class Sub
  attr_accessor :public, :static, :name, :generics, :args, :return_type, :body
  def initialize
    @generics = []
    @args = []
  end

  defined? $env or ($env = []).instance_exec do
    @statics = Hash.new { _1[_2] = {} }
    def self.statics = @statics
  end

  def ($env.statics['len'] = proc { INTEGER.new _1.length }).get = itself

  def run(*args, this:)
    $env.push '$this' => this

    unless args.length == @args.length
      raise "oops, you must call with exactly #{@args.length}, not #{args.length}" 
    end

    # TODO: typecheck args

    @args.zip(args).each do |n, a|
      $env.last[n] = a
    end

    catch :return do
      run_body
      nil
    end
  ensure
    $env.pop.each do |k, v|
      next if k == '$this' or @args.include? k
      # you forgot to delete your data, now enjoy a memory leak.
      ptr = Fiddle::Pointer.malloc ObjectSpace.memsize_of v
      ptr[0] = v
    end
  end

  private

  def run_body
    @body.strip!
    @body.gsub! /%.*\n/, '' # lol, if it's in a string youre screwed (or use `\p`)
    check_for_statics! unless @checked_for_statics
    body = +@body
    check_for_variable_declarations body
    nil while execute_statement body
  end

  def check_for_statics!
    @checked_for_statics = true

    while @body.slice! /\A\s*static\b/i
      @body.slice!(/\A\s*(\*\s*)*[a-zA-Z]\w*\s*/) or raise "expected type for static"
      type = $&.gsub /\s/, ''
      @body.slice!(/\A\s*\w+\s*/) or raise "expected name for static"
      name = $&.gsub(/\s/, '').downcase
      if @body.slice! /\A\s*=/
        init = @body.slice!(/\A[^;]*/) or fail "expected init after `=`"
        init = execute_expression init, @body
      end
      raise "expected `;` after static" unless @body.slice! /\A\s*;/
      $env.statics[self][name] = Container.new type: type, value: init
    end
  end

  def check_for_variable_declarations body
    return unless body.slice! /\A\s*var\b\s*/

    while body.slice! /\A\s*\w+\b/
      $env.last[$&.strip] = Container.new
      break unless  body.delete_prefix! ','
    end
  end

  def lookup_variable(name)
    $env.last[name] ||
      $env.statics[name] ||
      $env.statics.dig(self, name) ||
      $env.statics.dig($env.last['$self'], name) or fail "unknown variable #{name}"
  end


  def execute_statement body
    return if body.tap(&:strip!).empty?
    statement = body.slice!(/\A(?:\\.|[^\n])*(\n|\Z)/m) or return
    return execute_statement body if statement.tap(&:strip!).empty?

    case statement
    when /\A((?:\*\s*)*)\s*(\w+)\s*(:)=/ then # assignment, mayb w ptrs
      depth = $1.length
      container = lookup_variable $2
      value = execute_expression $', body

      depth.times { container = container.get }
      container.set value, first_time: $3
    when /\Areturn\b/i then throw :return, execute_expression($', body)
    when /\Adelete\b/i then
      $env.last.delete $'.strip
    else
      execute_expression statement, body
    end
    true
  end

  def precedence op
    case op
    when '==', '!=', '<', '<=', '>', '>=' then 0
    when '+', '-' then 1
    when '*', '/' then 2
    else raise "unknown op '#{op.inspect}'"
    end
  end

=begin
expression
 := ident ('+' | '-' | '*' | '/' | '%') ident 'OrElse' <statement>
  | ident ('++' | '--')
  | '*' {'*'} ident
  | '&' {'&'} ident
  | <literal>
  | ident '(' [<expression> {',' <expression>} [',']] ')'
  ;
=end

  def execute_expression expr, base 
    expr.strip!
    case expr
    when /^(?:\+\+|\-\-)\s*(\w+)$/, /^(\w+)\s*(?:\+\+|\-\-)$/ then
      val = lookup_variable $1
      val.set val + if $&.include? '+' then 1 else -1 end
    when /^(\&+)\s*(\w+)$/ then
      ptr = lookup_variable $2
      $1.length.times { ptr = POINTER.new ptr }
      ptr
    when /^(\**)\s*(\w+)$/ then
      val = lookup_variable $2
      $1.length.times { val = val.get }
      val

    when /^\d+$/ then INTEGER.new $&.to_i
    when /\A(\w+)\s*\(/
      fn = lookup_variable($1).get
      base.prepend $'
      base.slice! /^(.*?)\)/ or fail "missing closing `)`"
      args = $1.split(',').map(&:strip)
      args.map! { |a| execute_expression a, "<todo, do we need something?>" }
      fn.call *args

    when /\A<\?xml\s+version="([^"]*)"\s*encoding="([^"]*)"\?>/i then
      version = $1
      encoding = $2
      expr = $'.concat base
      expr.slice!(/\A\s*<string>(.*?)<\/string>/) or fail "expected `<string>...</string>` after xml, gotr"
      base.replace expr
      expr.clear
      STRING.new $1.encode!(encoding), version

    when /\A\}\s*(unless|until)\b(.*);/i then throw :unless_or_until, [$1, $2]
    when /\Ado\s*\{/i then
      base.prepend $'

      starting_body = base.dup

      which, cond = catch :unless_or_until do
        execute_statement base until base.empty?
        fail "oops, base is empty!"
      end

      while_contents = starting_body[...starting_body.length - base.length - 1 - which.length].strip

      while p(execute_expression(cond, "<todo, should there be more here?>")).truthy? do
        tmp = while_contents.dup
        execute_statement tmp until tmp.empty?
      end
    when /([!<>]=?|==|\bmod\b|[-+*\/])/i
      l = execute_expression $`, "<none>"
      op = $&
      if %w[< > <= >= == !=].include? op then
        r = $'
      else
        # `OrElse` is purposfully required to be this case
        /\bOrElse\b/ =~ $' or fail "expected `OrElse` for arithmetic operation"
        r = $`
        (catchit = $').empty? and fail "expected rhs for `OrElse`"
      end
      r = execute_expression r, "<none>"
      catch :overflow do
        return case op.downcase
        when '+', '-', '*', '/', 'mod' then l.send op, r
        when '!' then BOOL.new !l # you still need a RHS, it's just ignored? lol
        when '<', '>', '<=', '>=', '!=', '==' then BOOL.new l.send op, r
        else raise "unknown op: #{op}"
        end
      end

      execute_statement $'

    when nil then raise "empty expression"
    else
      raise "unknown expression: #{expr}"
    end
  end

  def execute_expression1 expr
    stack = []
    op_stack = []

    was_last_token_binary_op = true
    until expr.empty?
      expr.strip!
      case
      when expr.slice!(/\A\&/)
        var = expr.slice!(/\A\w+\b/) or raise "oops, expected solely an identifier after `&`"
        stack.push POINTER.new lookup_variable var

      when expr.slice!(/\A(==|[<!>]=?|[-+*\/&]|\bmod\b)/)
        if was_last_token_binary_op
          case $1
          when '*'
            var = expr.slice!(/\A\w+\b/) or raise "oops, expected solely an identifier after `*`"
            stack.push lookup_variable(var).get.get
          else raise "??"
          end
        end

        while !op_stack.empty? && precedence(op_stack.last) >= precedence($1)
          l, r = stack.pop 2
          stack.push l.send op_stack.pop, r
        end
        op_stack.push $1
        was_last_token_binary_op = true
        next # skip the ending `was_last_token_binary_op = false`

      when expr.slice!(/\A\d+\b/) then stack.push INTEGER.new $&.to_i
      when expr.slice!(/\A\w+\b/) then stack.push lookup_variable($&).get
      when expr.slice!(/\A<?xml\s+version="([^"]*)"\s*encoding="([^"]*)"?>/)
        version = $1
        encoding = $2
        expr.slice!(/\A\s*<string>(.*?)<\/string>/) or fail "expected `<string>...</string>` after xml"
        stack.push STRING.new $1.encode!(encoding), version
      when expr.slice!(/\A\(/) then stack.push execute_expression expr, base
      when expr.slice!(/\A\)/) then break
      else
        raise "unexpected start of sub: #{expr[..10].inspect}"
      end
      was_last_token_binary_op = false
    end

    while op = op_stack.pop
      l, r = stack.pop 2
      stack.push l.send op, r
    end

    fail "expected only one thing on the stack: #{stack}" unless stack.one?
    fail "op stack not empty" unless op_stack.empty?
    stack.first
  end
end
