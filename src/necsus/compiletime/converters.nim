import std/[macros, options, sets]
import tools, codeGenInfo, archetype, systemGen, componentDef, directiveArg, tupleDirective, common
import ../runtime/query

let input {.compileTime.} = ident("input")
let output {.compileTime.} = ident("output")

proc read(fromArch: Archetype[ComponentDef], arg: DirectiveArg): NimNode {.used.} =
    let readExpr = nnkBracketExpr.newTree(input, newLit(fromArch.indexOf(arg.component)))
    return if arg.isPointer: nnkAddr.newTree(readExpr) else: readExpr

proc copyTuple(fromArch: Archetype[ComponentDef], directive: TupleDirective): NimNode =
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

proc buildConverterProc(ctx: GenerateContext, convert: ConverterDef): NimNode {.used.} =
    ## Builds a single converter proc
    let name = ctx.converterName(convert)
    let inputTuple = convert.input.asStorageTuple
    let outputTuple = convert.output.asTupleType
    let body = copyTuple(convert.input, convert.output)
    return quote do:
        proc `name`(`input`: ptr `inputTuple`, `output`: var `outputTuple`) {.gcsafe, raises: [], fastcall, used.} =
            if not `input`.isNil:
                `body`

proc createConverterProcs*(details: CodeGenInfo): NimNode =
    ## Creates a list of procs for converting from one tuple type to another
    result = newStmtList()

    when not isFastCompileMode():
        var built = initHashSet[ConverterDef]()
        let ctx = details.newGenerateContext(Outside)
        for arg in details.allArgs:
            for convert in converters(ctx, arg):
                if convert notin built:
                    built.incl(convert)
                    result.add(ctx.buildConverterProc(convert))