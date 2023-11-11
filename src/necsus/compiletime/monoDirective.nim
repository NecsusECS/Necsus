import hashes, nimNode, strutils

type
     MonoDirective* = object of RootObj
        ## Parsed definition of a mono directive
        argType*: NimNode
        name*: string

proc newMonoDir*(argType: NimNode): MonoDirective =
    ## Create a new mono directive
    MonoDirective(argType: argType, name: argType.symbols.join("_"))

proc hash*(directive: MonoDirective): Hash = hash(directive.argType)

proc `==`*(a, b: MonoDirective): bool = cmp(a.argType, b.argType) == 0