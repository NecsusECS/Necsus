import std/[macros, options, algorithm, macrocache]
import tools, systemGen, componentDef, directiveArg, tupleDirective, common
import ../runtime/query

let input {.compileTime.} = ident("input")
let adding {.compileTime.} = ident("adding")
let output {.compileTime.} = ident("output")

proc read(arg: DirectiveArg, source: NimNode, index: int): NimNode =
    assert(index != -1, "Component is not present: " & $arg)
    let readExpr = nnkBracketExpr.newTree(source, newLit(index))
    return if arg.isPointer: nnkAddr.newTree(readExpr) else: readExpr

proc read(fromArch: openarray[ComponentDef], newVals: openarray[ComponentDef], arg: DirectiveArg): NimNode =
    let newValIdx = newVals.binarySearch(arg.component)
    if newValIdx >= 0:
        return read(arg, adding, newValIdx)
    else:
        return read(arg, input, fromArch.binarySearch(arg.component))

proc copyTuple(fromArch: openarray[ComponentDef], newVals: openarray[ComponentDef], directive: TupleDirective): NimNode =
    ## Generates code for copying from one tuple to another
    result = newStmtList()
    for i, arg in directive.args:
        let value = case arg.kind
            of DirectiveArgKind.Exclude:
                newCall(nnkBracketExpr.newTree(bindSym("Not"), arg.type), newLit(0'i8))
            of DirectiveArgKind.Include:
                read(fromArch, newVals, arg)
            of DirectiveArgKind.Optional:
                if arg.component in fromArch or arg.component in newVals:
                    newCall(bindSym("some"), read(fromArch, newVals, arg))
                else:
                    newCall(nnkBracketExpr.newTree(bindSym("none"), arg.type))
        result.add quote do:
            `output`[`i`] = `value`

when NimMajor >= 2:
    const built = CacheTable("NecsusConverters")
else:
    import std/tables
    var built {.compileTime.} = initTable[string, NimNode]()

proc buildConverter*(convert: ConverterDef): NimNode =
    ## Builds a single converter proc
    let sig = convert.signature
    if sig in built:
        return newStmtList()

    let name = convert.name
    let inputTuple = convert.input.asTupleType
    let existingTuple = if convert.adding.len == 0:
            quote: (int, )
        else:
            convert.adding.asTupleType
    let outputTuple = convert.output.asTupleType

    let body = if isFastCompileMode(fastConverters):
        newStmtList()
    else:
        let copier = copyTuple(convert.input, convert.adding, convert.output)
        if convert.sinkParams:
            copier
        else:
            quote:
                if not `input`.isNil:
                    `copier`

    let paramKeyword = if convert.sinkParams: ident("sink") else: ident("ptr")

    result = quote do:
        proc `name`(
            `input`: `paramKeyword` `inputTuple`,
            `adding`: `paramKeyword` `existingTuple`,
            `output`: var `outputTuple`
        ) {.gcsafe, raises: [], fastcall, used.} =
            `body`

    built[sig] = result
