import hashes, nimNode, strutils, macros

type
     MonoDirective* = ref object
        ## Parsed definition of a mono directive
        argType*: NimNode
        name*: string

proc newMonoDir*(argType: NimNode): MonoDirective =
    ## Create a new mono directive
    result = new(MonoDirective)
    result.argType = argType
    result.name = argType.symbols.join("_")

proc hash*(directive: MonoDirective): Hash = hash(directive.argType)

proc `==`*(a, b: MonoDirective): bool = cmp(a.argType, b.argType) == 0

proc `$`*(dir: MonoDirective): string = dir.argType.lispRepr