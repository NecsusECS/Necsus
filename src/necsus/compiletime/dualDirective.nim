import componentDef, strutils, hashes, sequtils, macros

type
    DualDirective* = ref object
        ## A directive that contains two tuples
        first*: seq[ComponentDef]
        second*: seq[ComponentDef]
        name*: string

proc newDualDir*(args: openarray[NimNode]): DualDirective =
    ## Create a new dual directive
    result = DualDirective(
        first: args[0].children.toSeq.mapIt(newComponentDef(it)),
        second: args[1].children.toSeq.mapIt(newComponentDef(it)),
    )
    result.name = result.first.generateName & "_" & result.second.generateName

proc hash*(directive: DualDirective): Hash = hash(directive.first) !& hash(directive.second)

proc `$`*(dir: DualDirective): string =
    dir.name & "((" & join(dir.first, ", ") & "):(" & join(dir.second, ", ") & "))"

iterator items*(directive: DualDirective): ComponentDef =
    ## Produce all components in a directive
    for arg in directive.first: yield arg
    for arg in directive.second: yield arg