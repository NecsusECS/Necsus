import std/[macros, strutils, sets, tables]
import ../compiletime/[parse, systemGen]

proc modulePath(node: NimNode): string =
    ## Attempts to determine if there is a full path available for a given module
    if node.lineInfoObj.filename.startsWith(getProjectPath()):
        result = node.lineInfoObj.filename
        result.removePrefix(getProjectPath())
        result.removePrefix("/")
        result.removeSuffix(".nim")

proc getModule(node: NimNode): string =
    ## Returns the module path for a nim node
    case node.kind
    of nnkTypeDef, nnkPragmaExpr, nnkProcDef, nnkIdentDefs:
        return node[0].getModule()
    of nnkSym:
        let modulePath = node.modulePath
        if modulePath != "":
            return modulePath

        let ownerModule = node.owner.modulePath
        if ownerModule != "":
            return ownerModule

        let owner = node.owner
        if owner == node:
            return node.strVal
        elif owner.kind != nnkNilLit:
            let parent = owner.getModule
            if parent == "":
                return owner.strVal
            else:
                return parent & "/" & owner.strVal
    else:
        return ""

proc collectImports(node: NimNode, into: var HashSet[string]) =
    case node.kind
    of nnkSym:
        into.incl(node.getImpl.getModule())
    of nnkIdentDefs:
        node[1].collectImports(into)
    of nnkBracketExpr, nnkTupleTy:
        for child in node.children:
            child.collectImports(into)
    else:
        discard

proc collectImports(nodes: openarray[NimNode], into: var HashSet[string]) =
    for node in nodes:
        collectImports(node, into)

proc dumpImports(app: ParsedApp, systems: openarray[ParsedSystem]) =
    var imports = initHashSet[string]()
    for component in app.components:
        component.node.collectImports(imports)

    for system in systems:
        system.symbol.collectImports(imports)
        system.prefixArgs.collectImports(imports)
        for arg in system.allArgs:
            for node in arg.nodes:
                node.collectImports(imports)

    for moduleName in imports:
        if moduleName != "":
            echo "import ", moduleName, " {.all.}"

proc fixVarNames(node: NimNode, symbols: var TableRef[string, NimNode]): NimNode =
    ## Replaces any variable names that start with ':' with a copy/pastable name
    if node.kind == nnkSym and node.strVal.startsWith(':'):
        return symbols.mgetOrPut(node.strVal, genSym(nskLet, "tempValue"))
    elif node.len > 0:
        result = node.kind.newTree()
        for child in node:
            result.add(child.fixVarNames(symbols))
    else:
        return node

proc fixTempVars(output: NimNode): NimNode =
    ##
    ## Fixes situations where Nim produces invalid code, like this:
    ##
    ## appState.config =
    ##   let :tmp = 10000
    ##   newNecsusConf(:tmp, ceilDiv(:tmp, 3))
    ##
    case output.kind
    of nnkAsgn:
        if output[1].kind != nnkStmtListExpr:
            return output
        var repaired = newStmtList()
        repaired.add(output[1][0..<1])
        repaired.add(nnkAsgn.newTree(output[0], output[1][^1]))
        var symbols = newTable[string, NimNode]()
        return repaired.fixVarNames(symbols)
    of nnkStmtList, nnkProcDef:
        result = output.kind.newTree
        for child in output: result.add(child.fixTempVars())
    else:
        return output

proc dumpGeneratedCode*(output: NimNode, app: ParsedApp, systems: openarray[ParsedSystem]) =
    ## Prints the generated necsus app for debugging purposes
    echo "import std/[math, json, jsonutils, options, importutils]"
    echo "import necsus/runtime/[world, archetypeStore], necsus/util/[profile, tools, blockstore]"
    dumpImports(app, systems)

    echo "const DEFAULT_ENTITY_COUNT = 1_000"
    var line: string
    for rawLine in output.fixTempVars().repr.splitLines():
        line &= rawLine
            .replace("proc =destroy", "proc `=destroy`")
            .replace("proc =copy", "proc `=copy`")
            .replace("proc =copy", "proc `=copy`")
            .replace("`gensym", "_gensym")
        while "__" in line:
            line = line.replace("__", "_")

        if line.endsWith("addr") or line.endsWith("sink"):
            line &= " "
        else:
            echo line.strip(leading = false)
            line = ""

    echo line
