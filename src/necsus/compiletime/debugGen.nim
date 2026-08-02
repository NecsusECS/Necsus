import macros, options, tables
import common, archetype, componentDef, systemGen
import ../runtime/[world, archetypeStore, directives]

{.warning[UnusedImport]: off.}
import tools
{.warning[UnusedImport]: on.}

let entityId {.compileTime.} = ident("entityId")

let entityIndex {.compileTime.} = ident("entityIndex")

let entityArchetype {.compileTime.} = newDotExpr(entityIndex, ident("archetype"))

proc worldFields(name: string): seq[WorldField] =
  @[(name, bindSym("EntityDebug"))]

proc stringify[T](value: T): string {.raises: [], gcsafe.} =
  ## Converts a value to a string as best as it can
  try:
    when compiles($value):
      return $value
    elif compiles(value.repr):
      return value.repr
    else:
      return $T
  except:
    return $T & "(Failed to generate string)"

proc buildArchetypeLookup(
    details: GenerateContext, archetype: Archetype[ComponentDef]
): NimNode =
  ## Builds the block of code for describing an entity out of a specific archetype.
  let archetypeIdent = archetype.ident
  let index = genSym(nskLet, "index")

  # This is bound here rather than left to be resolved where this code is pasted, so that
  # a name in the app being generated can not shadow it
  let getColumn = bindSym("getColumn")

  let archetypeIdentVar =
    newLit(" = " & archetype.readableName & " (" & archetype.idSymbol.strVal & ")")

  var str = quote:
    $`entityId` & `archetypeIdentVar`

  for comp in archetype:
    let label = newLit("; " & comp.readableName & " = ")
    let columnId = comp.columnId
    let readColumn = nnkBracketExpr.newTree(getColumn, comp.ident)

    # An accessory belongs to the entity rather than to the archetype, so having a column
    # for one says nothing about whether this entity is one of the ones that has it
    let value =
      if comp.isAccessory:
        let readPresence = nnkBracketExpr.newTree(getColumn, bindSym("AccessoryFlag"))
        let presenceId = comp.presenceColumnId
        quote:
          if `readPresence`(`appStateIdent`.`archetypeIdent`, `presenceId`)[`index`]:
            stringify(
              `readColumn`(`appStateIdent`.`archetypeIdent`, `columnId`)[`index`]
            )
          else:
            "none"
      else:
        quote:
          stringify(`readColumn`(`appStateIdent`.`archetypeIdent`, `columnId`)[`index`])

    str = quote:
      `str` & `label` & `value`

  return quote:
    let `index` = uint32(`entityIndex`.archetypeIndex)
    return `str`

proc generateEntityDebug(
    details: GenerateContext, arg: SystemArg, name: string
): NimNode =
  ## Generates the code for debugging the state of an entity
  if isFastCompileMode(fastDebugGen):
    return newEmptyNode()

  let debugProc = details.globalName(name)

  case details.hook
  of GenerateHook.Outside:
    let appType = details.appStateTypeName

    # Create a case statement where each branch is one of the archetypes
    var cases = newEmptyNode()

    when not defined(release):
      if details.archetypes.len > 0:
        cases = nnkCaseStmt.newTree(entityArchetype)
        for (ofBranch, archetype) in archetypeCases(details):
          cases.add(
            nnkOfBranch.newTree(ofBranch, details.buildArchetypeLookup(archetype))
          )
        cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))

    return quote:
      proc `debugProc`(
          `appStateIdent`: ptr `appType`, `entityId`: EntityId
      ): string {.nimcall, gcsafe, raises: [Exception].} =
        let `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]

        if unlikely(`entityIndex` == nil):
          return "No such entity: " & $`entityId`
        else:
          `cases`

  of GenerateHook.Standard:
    let procName = ident(name)
    return quote:
      `appStateIdent`.`procName` = proc(
          `entityId`: EntityId
      ): string {.closure, gcsafe, raises: [Exception].} =
        return `debugProc`(`appStatePtr`, `entityId`)
  else:
    return newEmptyNode()

let entityDebugGenerator* {.compileTime.} = newGenerator(
  ident = "EntityDebug",
  interest = {Standard, Outside},
  generate = generateEntityDebug,
  worldFields = worldFields,
)
