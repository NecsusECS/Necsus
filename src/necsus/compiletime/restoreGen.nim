import std/[json, macros]
import systemGen, common, ../runtime/directives

proc worldFields(name: string): seq[WorldField] =
  @[(name, bindSym("Restore"))]

let jsonArg {.compileTime.} = "json".ident

proc generate(details: GenerateContext, arg: SystemArg, name: string): NimNode =
  let wrapperName = details.globalName(name)

  case details.hook
  of Outside:
    let appType = details.appStateTypeName
    return quote:
      proc `wrapperName`(
          `appStatePtr`: pointer, `jsonArg`: string
      ) {.
          nimcall,
          gcsafe,
          raises: [IOError, OSError, JsonParsingError, ValueError, Exception],
          used
      .} =
        restore(cast[ptr `appType`](`appStatePtr`), `jsonArg`)

  of Late:
    let nameIdent = name.ident
    return quote:
      `appStateIdent`.`nameIdent` = newCallbackDir(`appStatePtr`, `wrapperName`)
  else:
    return newEmptyNode()

let restoreGenerator* {.compileTime.} = newGenerator(
  ident = "Restore",
  interest = {Late, Outside},
  generate = generate,
  worldFields = worldFields,
)
