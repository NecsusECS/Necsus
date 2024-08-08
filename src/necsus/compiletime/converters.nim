import std/[macros, options]
import tools, systemGen, componentDef, directiveArg, tupleDirective, common, archetype
import ../runtime/[query, archetypeStore]

let input {.compileTime.} = ident("input")
let adding {.compileTime.} = ident("adding")
let output {.compileTime.} = ident("output")

type TupleAdapter* = ref object
    ## Data for reading from a value from one tuple and outputing another
    source: NimNode
    index: int
    optionIn, optionOut, pointerOut: bool

proc newAdapter*(
    fromArch: Archetype[ComponentDef],
    newVals: openArray[ComponentDef],
    produce: DirectiveArg | ComponentDef,
    addingSource: NimNode = adding,
    existingSource: NimNode = input
): TupleAdapter =
    ## Data for reading from a value from one tuple and outputing another
    let output = when produce is ComponentDef:
        newDirectiveArg(produce, false, if produce.isAccessory: Optional else: Include)
    else:
        produce

    let newValIdx = newVals.find(output.component)
    if newValIdx >= 0:
        result = TupleAdapter(source: addingSource, index: newValIdx, optionIn: false)
    else:
        result = TupleAdapter(
            source: existingSource,
            index: fromArch.find(output.component),
            optionIn: fromArch.isAccessory(output.component)
        )
    result.pointerOut = output.isPointer
    result.optionOut = output.kind == Optional

proc addAccessoryCondition(existing: NimNode, adapter: TupleAdapter, predicate: NimNode): NimNode =
    ## Adds a boolean check to see if an accessory component passes a predicate
    if adapter.optionIn and not adapter.optionOut:
        let read = nnkBracketExpr.newTree(adapter.source, adapter.index.newLit)
        return quote: `existing` and `predicate`(`read`)
    else:
        return existing

proc build*(adapter: TupleAdapter): NimNode =
    assert(adapter.index != -1, "Component is not present: " & $output)
    result = nnkBracketExpr.newTree(adapter.source, newLit(adapter.index))
    if not adapter.optionIn or not adapter.optionOut or adapter.pointerOut:
        if adapter.optionIn:
            result = newCall(bindSym("get"), result)
        if adapter.pointerOut:
            result = nnkAddr.newTree(result)
        if adapter.optionOut:
            result = newCall(bindSym("some"), result)

proc copyTuple(fromArch: Archetype[ComponentDef], newVals: openarray[ComponentDef], directive: TupleDirective): NimNode =
    ## Generates code for copying from one tuple to another
    result = newStmtList()
    var condition = newLit(true)
    var tupleConstr = nnkTupleConstr.newTree()
    for i, arg in directive.args:
        let adapter = newAdapter(fromArch, newVals, arg)

        let value = case arg.kind
            of DirectiveArgKind.Exclude:
                condition = condition.addAccessoryCondition(adapter, bindSym("isNone"))
                newCall(nnkBracketExpr.newTree(bindSym("Not"), arg.type), newLit(0'i8))

            of DirectiveArgKind.Include:
                if adapter.optionIn:
                    condition = condition.addAccessoryCondition(adapter, bindSym("isSome"))
                adapter.build()

            of DirectiveArgKind.Optional:
                if adapter.index >= 0:
                    adapter.build()
                else:
                    newCall(nnkBracketExpr.newTree(bindSym("none"), arg.type))

        tupleConstr.add(value)

    return quote:
        if `condition`:
            `output` = `tupleConstr`
            return ConvertSuccess
        return ConvertSkip

when NimMajor >= 2:
    import std/macrocache
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
    let inputTuple = convert.input.asStorageTuple
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
            quote:
                `copier`
        else:
            quote:
                if not `input`.isNil:
                    `copier`
                return ConvertEmpty

    let paramKeyword = if convert.sinkParams: ident("sink") else: ident("ptr")

    result = quote do:
        proc `name`(
            `input`: `paramKeyword` `inputTuple`,
            `adding`: `paramKeyword` `existingTuple`,
            `output`: var `outputTuple`
        ): ConvertResult {.gcsafe, raises: [], fastcall, used.} =
            `body`

    built[sig] = result
