def slice!(...)
  $last = $code.slice! /\A([\s\n]|%.*\n)*/
  $code.slice!(...)
end

def identifier! = slice!(/\A(\w+)\b/)
