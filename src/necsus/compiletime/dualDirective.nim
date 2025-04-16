import componentDef, strutils, hashes, directiveArg

type DualDirective* = ref object ## A directive that contains two tuples
  first*: seq[DirectiveArg]
  second*: seq[DirectiveArg]
  name*: string

proc newDualDir*(first: seq[DirectiveArg], second: seq[DirectiveArg]): DualDirective =
  ## Create a new dual directive
  return DualDirective(
    first: first, second: second, name: first.generateName & "_" & second.generateName
  )

proc hash*(directive: DualDirective): Hash =
  hash(directive.first) !& hash(directive.second)

proc `$`*(dir: DualDirective): string =
  dir.name & "((" & join(dir.first, ", ") & "):(" & join(dir.second, ", ") & "))"

iterator items*(directive: DualDirective): ComponentDef =
  ## Produce all components in a directive
  for arg in directive.first:
    yield arg.component
  for arg in directive.second:
    yield arg.component
