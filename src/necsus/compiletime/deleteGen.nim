import std/[tables, macros, options]
import
  archetype, tools, systemGen, archetypeBuilder, common, tupleDirective, componentDef
import ../runtime/[archetypeStore, world, directives]

proc deleteFields(name: string): seq[WorldField] =
  @[(name, bindSym("Delete"))]

let entity {.compileTime.} = ident("entity")
let entityIndex {.compileTime.} = ident("entityIndex")

proc deleteProcName(details: GenerateContext): NimNode =
  return details.globalName("internalDelete")

proc buildArchetypeDelete(archetype: Archetype[ComponentDef]): NimNode =
  ## Builds the block of code for removing a row from a specific archetype.
  ## A column does not know what it holds, so the value in each one has to be destroyed
  ## by the site that does. Only once every column is out of the way can the row itself
  ## go, because dropping the row is what says the archetype got shorter
  let archIdent = archetype.ident
  let index = genSym(nskLet, "index")
  let moved = genSym(nskLet, "moved")

  # These are bound here rather than left to be resolved where this code is pasted, so that
  # a name in the app being generated can not shadow them
  let dropColumn = bindSym("dropColumn")
  let dropRow = bindSym("dropRow")

  result = newStmtList()
  result.add(
    newLetStmt(
      index, newCall(ident("uint32"), newDotExpr(entityIndex, ident("archetypeIndex")))
    )
  )

  for component in archetype.values:
    result.add(
      newCall(
        nnkBracketExpr.newTree(dropColumn, component.columnType),
        newDotExpr(appStateIdent, archIdent),
        component.columnId,
        index,
      )
    )

  # The last row gets moved down to fill the hole, which leaves whichever entity was
  # sitting in it pointing at the wrong index. Nothing moves when the deleted row was
  # already the last one, and that is what dropRow handing back the deleted entity means
  result.add quote do:
    let `moved` = `dropRow`(`appStateIdent`.`archIdent`, `index`)
    if `moved` != `entity`:
      `appStateIdent`.`worldIdent`[`moved`].archetypeIndex = uint(`index`)

proc generateDelete(details: GenerateContext, arg: SystemArg, name: string): NimNode =
  ## Generates the code for deleting an entity

  let deleteProcName = details.deleteProcName

  case details.hook
  of Outside:
    let appStateTypeName = details.appStateTypeName

    let body =
      if isFastCompileMode(fastDelete):
        newStmtList()
      else:
        var cases: NimNode
        if details.archetypes.len > 0:
          cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))
          for (ofBranch, archetype) in archetypeCases(details):
            cases.add(nnkOfBranch.newTree(ofBranch, buildArchetypeDelete(archetype)))

          cases.add(nnkElse.newTree(nnkDiscardStmt.newTree(newEmptyNode())))
        else:
          cases = newEmptyNode()

        let log = emitEntityTrace("Deleting ", entity)

        quote:
          let deleted = del(`appStateIdent`.`worldIdent`, `entity`)
          if likely(isSome(deleted)):
            let `entityIndex` = unsafeGet(deleted)
            `log`
            `cases`

    return quote:
      proc `deleteProcName`(
          `appStateIdent`: ptr `appStateTypeName`, `entity`: EntityId
      ) {.gcsafe, raises: [], nimcall, used.} =
        `body`

  of Standard:
    let deleteProc = name.ident
    return quote:
      `appStateIdent`.`deleteProc` = proc(`entity`: EntityId) {.gcsafe, raises: [].} =
        `deleteProcName`(`appStatePtr`, `entity`)
  else:
    return newEmptyNode()

let deleteGenerator* {.compileTime.} = newGenerator(
  ident = "Delete",
  interest = {Standard, Outside},
  generate = generateDelete,
  worldFields = deleteFields,
)

proc deleteAllFields(name: string, dir: TupleDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("DeleteAll"), dir.asTupleType))]

proc deleteAllBody(details: GenerateContext, dir: TupleDirective): NimNode =
  let deleteProcName = details.deleteProcName
  result = newStmtList()
  for archetype in details.archetypes:
    if archetype.matches(dir.filter):
      let archetypeIdent = archetype.ident
      # Deleting a row moves the last one into the hole it leaves, so walking forwards would
      # step straight over whichever entity just got moved down. Taking the last row every
      # time is the one order where nothing has to move at all
      result.add quote do:
        while rows(`appStateIdent`.`archetypeIdent`) > 0'u32:
          `deleteProcName`(
            `appStateIdent`,
            entityId(
              `appStateIdent`.`archetypeIdent`,
              rows(`appStateIdent`.`archetypeIdent`) - 1'u32,
            ),
          )

proc generateDeleteAll(
    details: GenerateContext, arg: SystemArg, name: string, dir: TupleDirective
): NimNode =
  if isFastCompileMode(fastDeleteGen):
    return newEmptyNode()

  let deleteAllImpl = details.globalName(name)

  case details.hook
  of Outside:
    let appStateTypeName = details.appStateTypeName
    let body = details.deleteAllBody(dir)
    return quote:
      proc `deleteAllImpl`(
          `appStateIdent`: ptr `appStateTypeName`
      ) {.gcsafe, nimcall.} =
        `body`

  of Standard:
    let ident = name.ident
    return quote:
      `appStateIdent`.`ident` = proc() =
        `deleteAllImpl`(`appStatePtr`)
  else:
    return newEmptyNode()

proc deleteAllNestedArgs(dir: TupleDirective): seq[RawNestedArg] =
  @[(newEmptyNode(), "del".ident, bindSym("Delete"))]

let deleteAllGenerator* {.compileTime.} = newGenerator(
  ident = "DeleteAll",
  interest = {Standard, Outside},
  generate = generateDeleteAll,
  worldFields = deleteAllFields,
  nestedArgs = deleteAllNestedArgs,
)
