import hashes, macros

type
    LocalDef* = object
        ## Parsed definition of a local directive
        argName: string
        argType*: NimNode
        id: int

# Every local def gets a unique id to ensure the same local variables aren't shared between systems
var id {.compileTime.} = 0

proc newLocalDef*(argName: string, argType: NimNode): LocalDef =
    ## Create a new LocalDef
    result = LocalDef(argName: argName, argType: argType, id: id)
    id = id + 1

proc hash*(local: LocalDef): Hash = hash(local.argName) !& hash(local.argType.strVal) !& local.id

proc `==`*(a, b: LocalDef): bool =
    a.argName == b.argName and a.argType == b.argType and a.id == b.id

proc generateName*(local: LocalDef): string =
    local.argName & "_" & local.argType.strVal & "_" & $local.id
