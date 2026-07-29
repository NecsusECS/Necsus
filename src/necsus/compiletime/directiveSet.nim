import tables, sequtils, strutils, strformat

type DirectiveSet*[T] = ref object ## All possible directives
  symbol: string
  values: OrderedTable[T, string]

proc newDirectiveSet*[T](prefix: string, values: openarray[T]): DirectiveSet[T] =
  ## Create a set of all directives in a set of systems
  result.new
  result.symbol = prefix & $T

  result.values = initOrderedTable[T, string]()
  var suffixes = initTable[string, int]()

  for value in values.toSeq.deduplicate:
    let name = toLowerAscii(prefix) & "_" & value.name
    let suffix = suffixes.mgetOrPut(name, 0)
    suffixes[name] = suffix + 1
    result.values[value] = name & "_" & $suffix

proc directives*[T](directives: DirectiveSet[T]): seq[T] =
  ## Produce all directives
  directives.values.keys.toSeq

iterator pairs*[T](directives: DirectiveSet[T]): tuple[name: string, value: T] =
  ## Produce all directives and their property names
  for (value, name) in directives.values.pairs:
    yield (name, value)

proc symbol*[T](directives: DirectiveSet[T]): string =
  ## Returns the name of this query set
  directives.symbol

proc `$`*[T](directives: DirectiveSet[T]): string =
  ## Returns the name of this query set
  &"{directives.symbol}({directives.directives})"

proc nameOf*[T](directives: DirectiveSet[T], value: T): string =
  ## Returns the name of a directive. Every name is built with a prefix and a suffix, so
  ## an empty string can only mean the lookup missed
  result = directives.values.getOrDefault(value, "")
  if result == "":
    raise newException(
      KeyError, &"Directive {value} was not in directiveSet: {directives}"
    )
