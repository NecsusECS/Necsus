import entityId, std/[json, options]

when defined(necsusFloat32):
    type Nfloat* = float32
else:
    type Nfloat* = float

type
    CallbackDir[T] = ref object
        ## A directive that uses a callback for interacting with a system
        appState: pointer
        callback: T

    Arity0Proc[T] = proc(app: pointer): T {.gcsafe, raises: [], fastcall.}
        ## A directive callback that just returns a value to our customers

    Arity1Proc[A, T] = proc(app: pointer, arg: A): T {.gcsafe, raises: [], fastcall.}
        ## A directive callback that accepts 1 parameter and returns

    Delete* = CallbackDir[Arity1Proc[EntityId, void]]
        ## Deletes an entity and all associated components

    Attach*[C: tuple] = proc(entityId: EntityId, components: C) {.gcsafe, raises: [].}
        ## Describes a type that is able to update existing entities new entities. Where `C` is
        ## a tuple with all the components to attach.

    Detach*[C: tuple] = CallbackDir[Arity1Proc[EntityId, void]]
        ## Detaches a set of components from an entity. Where `C` is a tuple describing all
        ## the components to detach

    Swap*[A: tuple, B: tuple] = proc(entityId: EntityId, components: A) {.gcsafe, raises: [].}
        ## A directive that adds components in `A` and removes components in `B`

    LookupProc[C: tuple] = proc(app: pointer, entityId: EntityId, components: var C): bool {.fastcall, gcsafe, raises: [].}

    Lookup*[C: tuple] = CallbackDir[LookupProc[C]]
        ## Looks up entity details based on its entity ID. Where `C` is a tuple with all the
        ## components to fetch

    TimeDelta* = CallbackDir[Arity0Proc[Nfloat]]
        ## Tracks the amount of time since the last execution of a system

    TimeElapsed* = CallbackDir[Arity0Proc[Nfloat]]
        ## The total amount of time spent in an app

    TickId* = CallbackDir[Arity0Proc[uint32]]
        ## An auto-incrementing ID for each tick

    EntityDebug* = CallbackDir[Arity1Proc[EntityId, string]]
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

proc newCallbackDir*[T : proc](appState: pointer, callback: T): CallbackDir[T] =
    ## Instantiates a directive that uses a callback
    return CallbackDir[T](appState: appState, callback: callback)

proc get*[C](lookup: Lookup[C], entityId: EntityId): Option[C] =
    ## Executes a lookup
    var output: C
    if lookup.callback(lookup.appState, entityId, output):
        return some(output)

{.experimental: "callOperator".}
proc `()`*[C](lookup: Lookup[C], entityId: EntityId): Option[C] =
    ## Executes a lookup
    lookup.get(entityId)

{.experimental: "dotOperators".}
proc `.()`*[C](obj: auto, lookup: Lookup[C], entityId: EntityId): Option[C] =
    ## Executes a lookup
    lookup.get(entityId)

proc get*[T](comp: CallbackDir[Arity0Proc[T]]): T =
    ## Fetch a value out of a single directive
    comp.callback(comp.appState)

{.experimental: "callOperator".}
proc `()`*[T](comp: CallbackDir[Arity0Proc[T]]): T =
    ## Fetch a value out of a single directive
    comp.get()

{.experimental: "dotOperators".}
proc `.()`*[T](parent: auto, comp: CallbackDir[Arity0Proc[T]]): T =
    ## Fetch a value out of a single directive
    comp.get()

proc get*[A, T](comp: CallbackDir[Arity1Proc[A, T]], a: A): T =
    ## Fetch a value out of a single directive
    comp.callback(comp.appState, a)

proc exec*[A](comp: CallbackDir[Arity1Proc[A, void]], a: A) =
    ## Fetch a value out of a single directive
    comp.callback(comp.appState, a)

{.experimental: "callOperator".}
proc `()`*[A, T](comp: CallbackDir[Arity1Proc[A, T]], a: A): T =
    ## Fetch a value out of a single directive
    comp.get(a)

{.experimental: "dotOperators".}
proc `.()`*[A, T](parent: auto, comp: CallbackDir[Arity1Proc[A, T]], a: A): T =
    ## Fetch a value out of a single directive
    comp.get(a)
