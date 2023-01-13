import worldEnum, parse, directiveSet, tupleDirective, monoDirective, componentDef, localDef, archetypeBuilder
import macros, sequtils, options, sets

type CodeGenInfo* = object
    ## Contains all the information needed to do high level code gen
    config*: NimNode
    app*: ParsedApp
    systems*: seq[ParsedSystem]
    queries*: DirectiveSet[QueryDef]
    spawns*: DirectiveSet[SpawnDef]
    attaches*: DirectiveSet[AttachDef]
    detaches*: DirectiveSet[DetachDef]
    locals*: DirectiveSet[LocalDef]
    shared*: DirectiveSet[SharedDef]
    lookups*: DirectiveSet[LookupDef]
    inboxes*: DirectiveSet[InboxDef]
    outboxes*: DirectiveSet[OutboxDef]
    components*: ComponentEnum
    archetypes*: ArchetypeSet[ComponentDef]
    archetypeEnum*: ArchetypeEnum

template directives[T](name: NimNode, app: ParsedApp, allSystems: openarray[ParsedSystem], extract: untyped): auto =
    ## Creates a directive set for a specific type of directive
    let fromSystems: seq[T] = allSystems.`extract`
    let fromApp: seq[T] = app.`extract`
    newDirectiveSet[T](name.strVal, concat(fromSystems, fromApp))

proc calculateArchetypes(
    spawns: DirectiveSet[SpawnDef],
    attaches: DirectiveSet[AttachDef],
    detaches: DirectiveSet[DetachDef]
): ArchetypeSet[ComponentDef] =
    ## Given all the directives, creates a set of required archetypes
    var builder = newArchetypeBuilder[ComponentDef]()

    for spawn in spawns: builder.define(spawn.value.comps)
    for attach in attaches: builder.attachable(attach.value.comps)
    for detach in detaches: builder.detachable(detach.value.comps)

    return builder.build()

proc newCodeGenInfo*(name: NimNode, config: NimNode, app: ParsedApp, allSystems: openarray[ParsedSystem]): CodeGenInfo =
    ## Collects data needed for code gen from all the parsed systems
    result.config = config
    result.app = app
    result.systems = allSystems.toSeq
    result.queries = directives[QueryDef](name, app, allSystems, queries)
    result.spawns = directives[SpawnDef](name, app, allSystems, spawns)
    result.attaches = directives[AttachDef](name, app, allSystems, attaches)
    result.detaches = directives[DetachDef](name, app, allSystems, detaches)
    result.locals = directives[LocalDef](name, app, allSystems, locals)
    result.shared = directives[SharedDef](name, app, allSystems, shared)
    result.lookups = directives[LookupDef](name, app, allSystems, lookups)
    result.inboxes = directives[InboxDef](name, app, allSystems, inboxes)
    result.outboxes = directives[OutboxDef](name, app, allSystems, outboxes)
    result.components = componentEnum(name.strVal, app, allSystems)
    result.archetypes = calculateArchetypes(result.spawns, result.attaches, result.detaches)
    result.archetypeEnum = archetypeEnum(name.strVal, result.archetypes)
