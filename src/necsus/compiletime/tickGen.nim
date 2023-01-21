import macros, sequtils, systemGen, tables, std/times
import codeGenInfo, parse, directiveSet, tupleDirective, monoDirective, commonVars

let timeDelta {.compileTime.} = ident("timeDelta")
let timeElapsed {.compileTime.} = ident("timeElapsed")

proc renderSystemArgs(codeGenInfo: CodeGenInfo, args: openarray[SystemArg]): seq[NimNode] =
    ## Renders system arguments down to nim code
    args.mapIt: codeGenInfo.directives[it.generator].nameOf(it).ident

proc callSystems(codeGenInfo: CodeGenInfo, systems: openarray[ParsedSystem]): NimNode =
    ## Generates the code for invoke a list of systems
    result = newStmtList()
    for system in systems:
        result.add(newCall(ident(system.symbol), codeGenInfo.renderSystemArgs(system.args)))

proc callTick(codeGenInfo: CodeGenInfo, runner: NimNode, body: NimNode): NimNode =
    ## Creates the code to invoke the runner
    var args = codeGenInfo.renderSystemArgs(codeGenInfo.app.runnerArgs)
    args.add(body)
    return newCall(runner, args)

proc createTickRunner*(codeGenInfo: CodeGenInfo, runner: NimNode): NimNode =
    ## Creates the code required to execute a single tick within the world
    let startups = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(it.phase == StartupPhase))
    let loopSystems = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(it.phase == LoopPhase))
    let teardown = codeGenInfo.callSystems(codeGenInfo.systems.filterIt(it.phase == TeardownPhase))

    let beforeLoop = codeGenInfo.generateForHook(GenerateHook.BeforeLoop)
    let loopStart = codeGenInfo.generateForHook(GenerateHook.LoopStart)
    let loopEnd = codeGenInfo.generateForHook(GenerateHook.LoopEnd)

    let primaryLoop = codeGenInfo.callTick(
        runner,
        quote do:
            let `thisTime` = epochTime()
            `loopStart`
            block:
                `loopSystems`
            `loopEnd`
    )

    result = quote do:
        `startups`
        let `startTime` = epochTime()
        `beforeLoop`
        `primaryLoop`
        `teardown`
