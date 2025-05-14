import std/[json, macros]
import systemGen, common, ../runtime/directives

proc worldFields(name: string): seq[WorldField] =
  @[(name, bindSym("Restore"))]

let jsonArg {.compileTime.} = "json".ident

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
  case details.hook
  of Late:
    let nameIdent = name.ident
    return quote:
      `appStateIdent`.`nameIdent` = proc(
          `jsonArg`: string
      ) {.gcsafe, raises: [IOError, OSError, JsonParsingError, ValueError, Exception].} =
        restore(`appStatePtr`, `jsonArg`)
  else:
    return newEmptyNode()

let restoreGenerator* {.compileTime.} = newGenerator(
  ident = "Restore", interest = {Late}, generate = generate, worldFields = worldFields
)
