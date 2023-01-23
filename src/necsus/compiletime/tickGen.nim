import macros, sequtils, systemGen, tables, std/times
import codeGenInfo, parse, directiveSet, tupleDirective, monoDirective, commonVars

proc renderSystemArgs(codeGenInfo: CodeGenInfo, args: openarray[SystemArg]): seq[NimNode] =
    ## Renders system arguments down to nim code
    args.mapIt: newDotExpr(appStateIdent, codeGenInfo.directives[it.generator].nameOf(it).ident)

proc callSystems*(codeGenInfo: CodeGenInfo, systems: openarray[ParsedSystem]): NimNode =
    ## Generates the code for invoke a list of systems
    result = newStmtList()
    for system in systems:
        result.add(newCall(ident(system.symbol), codeGenInfo.renderSystemArgs(system.args)))

proc createTickProc*(genInfo: CodeGenInfo): NimNode =
    ## Creates a function that executes the next tick
    let appStateType = genInfo.appStateTypeName

    let loopSystems = genInfo.callSystems(genInfo.systems.filterIt(it.phase == LoopPhase))

    let loopStart = genInfo.generateForHook(GenerateHook.LoopStart)
    let loopEnd = genInfo.generateForHook(GenerateHook.LoopEnd)

    return quote:
        proc tick(`appStateIdent`: var `appStateType`) =
            let `thisTime` = epochTime()
            `loopStart`
            block:
                `loopSystems`
            `loopEnd`

proc createTickRunner*(genInfo: CodeGenInfo, runner: NimNode): NimNode =
    ## Creates the code required to execute a single tick within the world
    var runnerArgs = genInfo.renderSystemArgs(genInfo.app.runnerArgs)
    runnerArgs.add(newStmtList(newCall(ident("tick"), appStateIdent)))
    return newCall(runner, runnerArgs)
