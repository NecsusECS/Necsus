import entityId, std/[json, options], macros

static:
  when not (compiles do:
    proc `()`[T](arg: T) = discard):
    error("Necsus must be compiled with --experimental:callOperator enabled")

type
  CallbackDir[T] = ref object
    ## A directive that uses a callback for interacting with a system
    appState: pointer
    callback: T

  Arity0Proc[T] = proc(app: pointer): T {.gcsafe, raises: [ValueError], nimcall.}
    ## A directive callback that just returns a value to our customers

  Arity1Proc[A, T] =
    proc(app: pointer, arg: A): T {.gcsafe, raises: [ValueError, Exception], nimcall.}
    ## A directive callback that accepts 1 parameter and returns

  Arity2Proc[A, B, T] =
    proc(app: pointer, a: A, b: B): T {.gcsafe, raises: [ValueError], nimcall.}
    ## A directive callback that accepts 2 parameters and returns

  Delete* = proc(eid: EntityId) {.gcsafe, raises: [ValueError], closure.}
    ## Deletes an entity and all associated components

  DeleteAll*[C: tuple] = proc() {.closure, gcsafe.}
    ## Deletes all entities matching a query

  Attach*[C: tuple] = CallbackDir[Arity2Proc[EntityId, C, void]]
    ## Describes a type that is able to update existing entities new entities. Where `C` is
    ## a tuple with all the components to attach.

  Detach*[C: tuple] = CallbackDir[Arity1Proc[EntityId, void]]
    ## Detaches a set of components from an entity. Where `C` is a tuple describing all
    ## the components to detach

  Swap*[A: tuple, B: tuple] = CallbackDir[Arity2Proc[EntityId, A, void]]
    ## A directive that adds components in `A` and removes components in `B`

  LookupProc[C: tuple] = proc(app: pointer, entityId: EntityId, components: var C): bool {.
    nimcall, gcsafe, raises: []
  .}

  Lookup*[C: tuple] = CallbackDir[LookupProc[C]]
    ## Looks up entity details based on its entity ID. Where `C` is a tuple with all the
    ## components to fetch

  OutboxProc*[T] = proc(app: pointer, message: T): void {.nimcall.}

  Outbox*[T] = CallbackDir[OutboxProc[T]]
    ## Sends an event. Where `T` is the message being sent

  TimeDelta* = CallbackDir[Arity0Proc[BiggestFloat]]
    ## Tracks the amount of time since the last execution of a system

  TimeElapsed* = CallbackDir[Arity0Proc[BiggestFloat]]
    ## The total amount of time spent in an app

  TickId* = CallbackDir[Arity0Proc[BiggestUInt]] ## An auto-incrementing ID for each tick

  EntityDebug* = CallbackDir[Arity1Proc[EntityId, string]]
    ## Looks up an entity and returns debug data about it

  Bundle*[T] = ptr T ## A group of directives bundled together in an object

  SaveProc = proc(app: pointer): string {.
    raises: [IOError, OSError, ValueError, Exception], nimcall
  .}

  Save* = CallbackDir[SaveProc] ## Generates a saved game state as a json value

  RestoreProc = proc(app: pointer, json: string) {.
    nimcall, gcsafe, raises: [IOError, OSError, JsonParsingError, ValueError, Exception]
  .}

  Restore* = CallbackDir[RestoreProc]
    ## Executes all 'restore' systems using the given json as input data

  SystemInstance* = proc(): void {.closure.}
    ## A callback used to invoke a specific system

  EventSystemInstance*[T] = proc(event: T): void {.closure.}
    ## Marks the return type for an instanced event system

  SaveSystemInstance*[T] = proc(): T {.closure.}
    ## Marks the return type for an instanced save system

proc newCallbackDir*[T: proc](appState: pointer, callback: T): CallbackDir[T] =
  ## Instantiates a directive that uses a callback
  return CallbackDir[T](appState: appState, callback: callback)

proc get*[C](lookup: Lookup[C], entityId: EntityId): Option[C] =
  ## Executes a lookup
  var output: C
  if lookup.callback(lookup.appState, entityId, output):
    return some(output)

proc `()`*[C](lookup: Lookup[C], entityId: EntityId): Option[C] =
  ## Executes a lookup
  lookup.get(entityId)

proc get*[T](comp: CallbackDir[Arity0Proc[T]]): T =
  ## Fetch a value out of a directive
  comp.callback(comp.appState)

proc `()`*[T](comp: CallbackDir[Arity0Proc[T]]): T =
  ## Fetch a value out of a directive
  comp.get()

proc get*[A, T](comp: CallbackDir[Arity1Proc[A, T]], a: A): T =
  ## Fetch a value out of a directive
  comp.callback(comp.appState, a)

proc exec*[A](comp: CallbackDir[Arity1Proc[A, void]], a: A) =
  ## Execute a directive
  comp.callback(comp.appState, a)

proc `()`*[A, T](comp: CallbackDir[Arity1Proc[A, T]], a: A): T =
  ## Fetch a value out of a directive
  comp.get(a)

proc get*[A, B, T](comp: CallbackDir[Arity2Proc[A, B, T]], a: A, b: B): T =
  ## Fetch a value out of a directive
  comp.callback(comp.appState, a, b)

proc exec*[A, B](comp: CallbackDir[Arity2Proc[A, B, void]], a: A, b: B) =
  ## Execute a directive
  comp.callback(comp.appState, a, b)

proc `()`*[A, B, T](comp: CallbackDir[Arity2Proc[A, B, T]], a: A, b: B): T =
  ## Fetch a value out of a directive
  comp.get(a, b)

proc `()`*(save: Save): string =
  ## Executes a save
  save.callback(save.appState)

proc `()`*(restore: Restore, value: string) =
  ## Executes a restore operation
  restore.callback(restore.appState, value)

proc exec*[T](outbox: Outbox[T], message: T) {.inline.} =
  ## Sends a message through an outbox
  outbox.callback(outbox.appState, message)

proc `()`*[T](outbox: Outbox[T], message: T) =
  ## Sends a message through an outbox
  outbox.exec(message)
