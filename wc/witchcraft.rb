require_relative 'klass'


parse_klasses! <<EOS; <<EOS
public static klass App:
  enter sub public static main(argc: int, argv: *string ---> void)
    static STRING percentS = <?xml version="1.0" encoding="UTF-8"?><string>\\Ps</string>;
    var max, fb, l

    max := 100

    do {
      1
      2
      3
      l := len(argv)
    } unless len == 1;
      % sscanf(@args[1], percentN, &max)

    % fb := new Fizzbuzz[int](max)
    % fb.play()
    delete fb
    delete max
  leave sub main

EOS
public klass Ary[t]:
  *t ptr;
  int len;
  int cap;

  enter sub __construct(cap: int)
    $this.ptr := alloc(cap)
    $this.len := 0
    $this.cap := cap
  leave sub __construct

  enter sub map[u](mapFn: FN_t__u --> Ary[u])
    var mapped, thisPtr, mappedPtr

    mapped := new Ary($this.len)
    thisPtr := $this.ptr
    mappedPtr := mapped.ptr

    do {
      *mappedPtr = mapFn(*thisPtr)
      mappedPtr++ OrElse throw witchcraft.arithmetic.OverflowError()
      thisPtr++ OrElse throw witchcraft.arithmetic.OverflowError()
      mapped.len++ OrElse throw witchcraft.arithmetic.OverflowError()
    } until mapped.len == $this.len;

    delete thisPtr
    delete mappedPtr

    return mapped
  leave sub map

klass App[T]:
  enter sub apply[U](ary: *T, len: int, fn: fn_T__U --> *T)
    var ret, ptr, i

    ret := alloc[T](len)
    i := 0
    ptr := ret

    do {
      *ptr = fn(*ary)
      ptr++
      ary++
    } until i == len;

    delete ptr
    delete i

    return ret
  leave sub apply

  public static STRING bar = 34;
  enter sub main(x: int --> int)
    static INT i1 = 1;
    static INT i2 = 2;

    var p1, p2

    p1 = &i1
    p2 = &p1
    *p2 = &i2

    return *p1
  leave sub main

  %    var s
  %    *isAllocated = false
  %
  %    do {
  %      return fizzbuzz
  %    } unless (num mod 15){ throw new witchcraft.arithmetic.OverflowError() };
  %
  %    do {
  %      return fizz
  %    } unless (num mod 3){ throw new witchcraft.arithmetic.OverflowError() };
  %
  %    do {
  %      return buzz
  %    } unless (num mod 5){ throw new witchcraft.arithmetic.OverflowError() };
  %
  %    s := <?xml version="1.0" encoding="UTF-8"?><string></string></xml>
  %    sprintf(@&s, percentN, num)
  %    *isAllocated = true
  %    return s


EOK

klass Fraction[T]:
  INT numer;
  INT denom;

  enter sub Fraction(numer: T, denom: T --> void)
    $this.numer = numer
    $this.denom = denom
  leave sub Fraction

  enter sub Fraction(--> void)
    $this.numer = numer
    $this.denom = denom
  leave sub Fraction
EOS
p $klasses['App'].subs['main'].run 0, [1,2,3], this: 3

__END__
    when stage == 5
      next if parsed == ','


      stage = 1
    elsif thing == 'static'
      $current_klass.static = true
      stage = 2
    elsif thing == 'klass'
    case thing
    when !$current_klass
      $current_klass = 
  end
end

$code = File.read '../example.wc'
parse! 


__END__
    if $current_klass
      case stage
      when 0 then klass.public = identifier! 'public'
      when 1 then klass.static = identifier! 'static'
      when 2 then 
        elsif identifier! 'static'
      end
      stage += 1


def klass!
  return if $current_klass

  $current_klass = klass = Klass.new

  klass.public = slice! /\Apublic\b/
  klass.static = slice! /\Astatic\b/

  raise "`klass` is expected at top level" unless slice! /\Aklass\b/

  klass.name = identifier! or raise "expected identifier after `klass`"
  klass.generics = []

  if slice! /\A\[/ then
    while p = identifier! do
      klass.generics << p
      slice! /\A\,/ or break
    end
    slice! /\A\]/ or raise "expected `]` after generics"
  end

  slice! /\A:/ or raise "expected `:` after klass."
end
