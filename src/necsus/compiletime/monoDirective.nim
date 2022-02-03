import hashes, macros, nimNode, strutils

template createDirective(typ: untyped) =
    ## Creates a new mono-directive

    type
        typ* = object
            ## Parsed definition of a mono directive
            argType*: NimNode

    proc `new typ`*(argType: NimNode): typ =
        ## Create a new mono directive
        typ(argType: argType)

    proc hash*(directive: typ): Hash = hash(directive.argType)

    proc `==`*(a, b: typ): bool = cmp(a.argType, b.argType) == 0

    proc generateName*(directive: typ): string =
        directive.argType.symbols.join("_")

createDirective(SharedDef)
createDirective(InboxDef)
createDirective(OutboxDef)
