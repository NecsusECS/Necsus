import hashes, nimNode, strutils

type
     MonoDirective* = object of RootObj
        ## Parsed definition of a mono directive
        argType*: NimNode

proc generateName*(directive: MonoDirective): string =
    directive.argType.symbols.join("_")

proc hash*(directive: MonoDirective): Hash = hash(directive.argType)

proc `==`*(a, b: MonoDirective): bool = cmp(a.argType, b.argType) == 0

template createDirective(typ: untyped) =
    ## Creates a new mono-directive

    proc `new typ`*(argType: NimNode): MonoDirective =
        ## Create a new mono directive
        MonoDirective(argType: argType)

createDirective(SharedDef)
createDirective(LocalDef)
createDirective(InboxDef)
createDirective(OutboxDef)
