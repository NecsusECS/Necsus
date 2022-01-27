import hashes, macros

template createDirective(typ: untyped) =
    ## Creates a new mono-directive

    type
        typ* = object
            ## Parsed definition of a mono directive
            argType*: NimNode

    proc `new typ`*(argType: NimNode): typ =
        ## Create a new mono directive
        typ(argType: argType)

    proc hash*(directive: typ): Hash = hash(directive.argType.strVal)

    proc `==`*(a, b: typ): bool = a.argType == b.argType

    proc generateName*(directive: typ): string =
        directive.argType.strVal

createDirective(SharedDef)
