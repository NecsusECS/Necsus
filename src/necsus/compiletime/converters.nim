import std/[macros, options, algorithm, macrocache, sets]
import tools, codeGenInfo, systemGen, componentDef, directiveArg, tupleDirective, common
import ../runtime/query

let input {.compileTime.} = ident("input")
let output {.compileTime.} = ident("output")

proc read(fromArch: openarray[ComponentDef], arg: DirectiveArg): NimNode =
    let index = fromArch.binarySearch(arg.component)
    assert(index != -1, "Component is not present: " & $arg)
    let readExpr = nnkBracketExpr.newTree(input, newLit(index))
    return if arg.isPointer: nnkAddr.newTree(readExpr) else: readExpr

proc copyTuple(fromArch: openarray[ComponentDef], directive: TupleDirective): NimNode =
    ## Generates code for copying from one tuple to another
    result = newStmtList()
    for i, arg in directive.args:
        let value = case arg.kind
            of DirectiveArgKind.Exclude:
                newCall(nnkBracketExpr.newTree(bindSym("Not"), arg.type), newLit(0'i8))
            of DirectiveArgKind.Include:
                read(fromArch, arg)
            of DirectiveArgKind.Optional:
                if arg.component in fromArch:
                    newCall(bindSym("some"), read(fromArch, arg))
                else:
                    newCall(nnkBracketExpr.newTree(bindSym("none"), arg.type))
        result.add quote do:
            `output`[`i`] = `value`

proc buildConverter*(convert: ConverterDef): NimNode =
    ## Builds a single converter proc
    let name = convert.name
    let inputTuple = convert.input.asTupleType
    let outputTuple = convert.output.asTupleType

    let body = if isFastCompileMode(fastConverters):
        newStmtList()
    else:
        copyTuple(convert.input, convert.output)

    return quote do:
        proc `name`(`input`: ptr `inputTuple`, `output`: var `outputTuple`) {.gcsafe, raises: [], fastcall, used.} =
            if not `input`.isNil:
                `body`

proc createConverterProcs*(details: CodeGenInfo): NimNode =
    ## Creates a list of procs for converting from one tuple type to another
    result = newStmtList()

    var built = initHashSet[ConverterDef]()
    let ctx = details.newGenerateContext(Outside)
    for arg in details.allArgs:
        for convert in converters(ctx, arg):
            if convert notin built:
                built.incl(convert)
                result.add(buildConverter(convert))