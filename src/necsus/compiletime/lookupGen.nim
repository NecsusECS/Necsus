import std/[macros, sequtils, tables, options]
import tupleDirective, tools, common, archetype, componentDef, systemGen
import ../runtime/[world, archetypeStore, query, directives]

let entityId {.compileTime.} = ident("entityId")
let entityIndex {.compileTime.} = ident("entityIndex")
let output {.compileTime.} = ident("output")

proc buildArchetypeLookup(
    details: GenerateContext,
    lookup: TupleDirective,
    tupleType: NimNode,
    archetype: Archetype[ComponentDef],
): NimNode =
  ## Builds the block of code for pulling a lookup out of a specific archetype.
  ##
  ## A lookup wants exactly one row out of one archetype, which is a query narrowed down to
  ## a single index -- so it resolves its columns the same way a query does and then reads
  ## the one row it came for
  let archetypeIdent = archetype.ident
  let ids = lookup.componentIds
  let accessories = lookup.accessoryArgs
  let cols = genSym(nskLet, "cols")

  # These are bound here rather than left to be resolved where this code is pasted, so that
  # a name in the app being generated can not shadow them
  let newQueryCols = bindSym("newQueryCols")
  let read = bindSym("read")

  # The read is what decides whether the lookup found anything, rather than the archetype
  # alone: an entity in a matching archetype can still be missing an accessory that was
  # asked for, because an accessory is present per entity
  return quote:
    let `cols` = `newQueryCols`[`tupleType`](
      `appStateIdent`.`archetypeIdent`, `ids`, `accessories`
    )
    return `read`(`cols`, uint32(`entityIndex`.archetypeIndex), `output`)

proc worldFields(name: string, dir: TupleDirective): seq[WorldField] =
  @[(name, nnkBracketExpr.newTree(bindSym("Lookup"), dir.asTupleType))]

proc generate(
    details: GenerateContext, arg: SystemArg, name: string, lookup: TupleDirective
): NimNode =
  ## Generates the code for instantiating queries
  if isFastCompileMode(fastLookup):
    return newEmptyNode()

  let lookupProc = details.globalName(name)
  let tupleType = lookup.args.toSeq.asTupleType

  case details.hook
  of GenerateHook.Outside:
    let appStateTypeName = details.appStateTypeName

    var cases: NimNode = newEmptyNode()
    if details.archetypes.len > 0:
      cases = nnkCaseStmt.newTree(newDotExpr(entityIndex, ident("archetype")))

      # Create a case statement where each branch is one of the archetypes
      for (ofBranch, archetype) in archetypeCases(details):
        if archetype.matches(lookup.filter):
          cases.add(
            nnkOfBranch.newTree(
              ofBranch, details.buildArchetypeLookup(lookup, tupleType, archetype)
            )
          )

      # Add a fall through 'else' branch for any archetypes that don't fit this lookup
      cases.add(nnkElse.newTree(nnkReturnStmt.newTree(newLit(false))))

    return quote:
      proc `lookupProc`(
          `appStateIdent`: ptr `appStateTypeName`,
          `entityId`: EntityId,
          `output`: var `tupleType`,
      ): bool {.nimcall, gcsafe, raises: [], used.} =
        let `entityIndex` {.used.} = `appStateIdent`.`worldIdent`[`entityId`]
        if unlikely(`entityIndex` == nil):
          return false
        `cases`

  of GenerateHook.Standard:
    let procName = ident(name)
    return quote:
      `appStateIdent`.`procName` = proc(`entityId`: EntityId): Option[`tupleType`] =
        var output: `tupleType`
        if `lookupProc`(`appStatePtr`, `entityId`, output):
          return some(output)
  else:
    return newEmptyNode()

let lookupGenerator* {.compileTime.} = newGenerator(
  ident = "Lookup",
  interest = {Standard, Outside},
  generate = generate,
  worldFields = worldFields,
)
