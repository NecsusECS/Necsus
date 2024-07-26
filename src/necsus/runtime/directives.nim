import entityId, std/[json, options]

when defined(necsusFloat32):
    type Nfloat* = float32
else:
    type Nfloat* = float

type

    Delete* = proc(entityId: EntityId) {.gcsafe, raises: [].}
        ## Deletes an entity and all associated components

    Attach*[C: tuple] = proc(entityId: EntityId, components: C) {.gcsafe, raises: [].}
        ## Describes a type that is able to update existing entities new entities. Where `C` is
        ## a tuple with all the components to attach.

    Detach*[C: tuple] = proc(entityId: EntityId) {.gcsafe, raises: [].}
        ## Detaches a set of components from an entity. Where `C` is a tuple describing all
        ## the components to detach

    Swap*[A: tuple, B: tuple] = proc(entityId: EntityId, components: A) {.gcsafe, raises: [].}
        ## A directive that adds components in `A` and removes components in `B`

    LookupProc[C: tuple] = proc(app: pointer, entityId: EntityId, components: var C): bool {.fastcall, gcsafe, raises: [].}

    Lookup*[C: tuple] = ref object
        ## Looks up entity details based on its entity ID. Where `C` is a tuple with all the
        ## components to fetch
        appState: pointer
        lookup: LookupProc[C]

    Outbox*[T] = proc(message: T): void
        ## Sends an event. Where `T` is the message being sent

    TimeDelta* = proc(): Nfloat {.gcsafe, raises: [].}
        ## Tracks the amount of time since the last execution of a system

    TimeElapsed* = proc(): Nfloat {.gcsafe, raises: [].}
        ## The total amount of time spent in an app

    TickId* = proc(): uint32 {.gcsafe, raises: [].}
        ## An auto-incrementing ID for each tick

    EntityDebug* = proc(entityId: EntityId): string {.gcsafe, raises: [].}
        ## Looks up an entity and returns debug data about it

    Bundle*[T] = ptr T
        ## A group of directives bundled together in an object

    Save* = proc(): string {.raises: [IOError, OSError, ValueError, Exception].}
        ## Generates a saved game state as a json value

    Restore* = proc(json: string) {.gcsafe, raises: [IOError, OSError, JsonParsingError, ValueError, Exception].}
        ## Executes all 'restore' systems using the given json as input data

    SystemInstance* = proc(): void {.closure.}
        ## A callback used to invoke a specific system

    EventSystemInstance*[T] = proc(event: T): void {.closure.}
        ## Marks the return type for an instanced event system

    SaveSystemInstance*[T] = proc(): T {.closure.}
        ## Marks the return type for an instanced save system

proc newLookup*[C](appState: pointer, lookup: LookupProc[C]): Lookup[C] =
    ## Creates a lookup instance
    return Lookup[C](appState: appState, lookup: lookup)

proc get*[C](lookup: Lookup[C], entityId: EntityId): Option[C] =
    ## Executes a lookup
    var output: C
    if lookup.lookup(lookup.appState, entityId, output):
        return some(output)

{.experimental: "callOperator".}
proc `()`*[C](lookup: Lookup[C], entityId: EntityId): Option[C] =
    ## Executes a lookup
    lookup.get(entityId)

{.experimental: "dotOperators".}
proc `.()`*[C](obj: auto, lookup: Lookup[C], entityId: EntityId): Option[C] =
    ## Executes a lookup
    lookup.get(entityId)
