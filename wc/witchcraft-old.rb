module Shared
  attr_accessor :public, :static, :name
end

class Kind
  attr_accessor :name, :is_array, :pointer_depth
end

class Sub
  include Shared
  attr_accessor :args, :return_type, :body
end

class Argument
  attr_accessor :name, :kind
end

class Field
  include Shared
  attr_accessor :kind, :init
end

class Klass
  include Shared
  attr_accessor :generics, :fields, :subs
end

def slice!(...)
  $last = $code.slice! /\A([\s\n]|%.*\n)*/
  $code.slice!(...)
end

def identifier = slice!(/\A(\w+)\b/)

def kind!
  kind = Kind.new
  kind.pointer_depth = slice!(/\A\**/)&.length || 0
  kind.name = identifier or fail "expected identifier in kind: #{$code.inspect}"
  kind.is_array = true if slice! /\A\[\]/
  kind
end

def field!
  field = Field.new
  field.public = true if slice! /\Apublic\b/
  field.static = true if slice! /\Astatic\b/
  field.kind = kind!
  field.name = identifier or fail "expected name for field"
  if slice! /\A=/ then
    field.init = slice!(/\A([^;]+);/)[..-2]
  else
    slice! /\A;/ or fail "expected `;` after field"
  end
  field
end

def klass!
  $current_klass = klass = Klass.new
  klass.public = true if slice! /\Apublic\b/
  klass.static = true if slice! /\Astatic\b/
  raise "`klass` is expected at top level" unless slice! /\Aklass\b/
  klass.name = identifier or raise "expected identifier after `klass`"
  klass.generics = []
  if slice! /\A\[/ then
    while p = identifier do
      klass.generics << p
      slice! /\A\,/ or break
    end
    slice! /\A\]/ or raise "expected `]` after generics"
  end
  slice! /\A:/ or raise "expected `:` after klass."

  klass.fields = []
  klass.subs = []

  loop do
    if slice! /\Aenter\s+sub\b/ then
      klass.subs << Sub.new
      klass.subs.last.public = true if slice! /\Apublic\b/
      klass.subs.last.static = true if slice! /\Astatic\b/
      klass.subs.last.name = identifier or fail "expected identifier after enter a sub"
      klass.subs.last.args = []
      if slice! /\A\(/ then
        until slice! /\A\)/ do
          if slice! /\A-{2,}>/ then
            klass.subs.last.return_type = kind! or fail "expected identifier for return type!"
            slice! /\A\)/ or raise "expected `)` after arguments: #{$code.inspect}"
            break
          end

          klass.subs.last.args << Argument.new
          klass.subs.last.args.last.name = identifier or fail "expected an identifier for argument name"
          slice! /\A:\s*/ or fail "expected `:` after argument name"
          klass.subs.last.args.last.kind = kind!

          unless slice! /\A\,/
            if slice! /\A-{2,}>/ then
              klass.subs.last.return_type = kind! or fail "expected identifier for return type!"
            end

            slice! /\A\)/ or raise "expected `)` after arguments: #{$code.inspect}"
            break
          end
        end
      end
      
      klass.subs.last.body = slice!(/\A(?:(?!leave sub #{klass.subs.last.name}).)*/m)
      slice! /\Aleave sub #{klass.subs.last.name}/ or fail "missing `leave sub #{klass.subs.last.name}`"
    elsif $code.slice!(/\A\s*?(\n\n|\z)/) || $last =~ /\n\n/
      break
    else
      klass.fields << field!
    end
  end

  klass
end

def parse! code
  $code = code
  $klasses = {}
  until (slice! //; $code.empty?) do
    klass = klass!
    $klasses[klass.name] = klass
  end
end


parse! open('example.wc', &:read)

p $klasses['App'].subs.find { _1.name == 'main' }
