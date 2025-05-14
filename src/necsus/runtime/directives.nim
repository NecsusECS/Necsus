import entityId, std/[json, options]

type
  Delete* = proc(eid: EntityId) {.gcsafe, raises: [ValueError], closure.}
    ## Deletes an entity and all associated components

  DeleteAll*[C: tuple] = proc() {.closure, gcsafe.}
    ## Deletes all entities matching a query

  Attach*[C: tuple] = proc(eid: EntityId, components: C) {.gcsafe, closure.}
    ## Describes a type that is able to update existing entities new entities. Where `C` is
    ## a tuple with all the components to attach.

  Detach*[C: tuple] = proc(eid: EntityId) {.gcsafe, closure.}
    ## Detaches a set of components from an entity. Where `C` is a tuple describing all
    ## the components to detach

  Swap*[A: tuple, B: tuple] = proc(eid: EntityId, newComps: A) {.gcsafe, closure.}
    ## A directive that adds components in `A` and removes components in `B`

  Lookup*[C: tuple] =
    proc(entityId: EntityId): Option[C] {.closure, gcsafe, raises: [].}
    ## Looks up entity details based on its entity ID. Where `C` is a tuple with all the
    ## components to fetch

  Outbox*[T] = proc(message: T) {.closure, gcsafe.}
    ## Sends an event. Where `T` is the message being sent

  TimeDelta* = proc(): BiggestFloat {.closure, gcsafe.}
    ## Tracks the amount of time since the last execution of a system

  TimeElapsed* = proc(): BiggestFloat {.closure, gcsafe.}
    ## The total amount of time spent in an app

  TickId* = proc(): BiggestUInt {.closure, gcsafe.}
    ## An auto-incrementing ID for each tick

  EntityDebug* = proc(eid: EntityId): string {.gcsafe, closure, raises: [Exception].}
    ## Looks up an entity and returns debug data about it

  Bundle*[T] = ptr T ## A group of directives bundled together in an object

  Save* = proc(): string {.raises: [IOError, OSError, ValueError, Exception], closure.}
    ## Generates a saved game state as a json value

  Restore* = proc(json: string) {.
    closure, gcsafe, raises: [IOError, OSError, JsonParsingError, ValueError, Exception]
  .} ## Executes all 'restore' systems using the given json as input data

  SystemInstance* = proc(): void {.closure.}
    ## A callback used to invoke a specific system

  EventSystemInstance*[T] = proc(event: T): void {.closure.}
    ## Marks the return type for an instanced event system

  SaveSystemInstance*[T] = proc(): T {.closure.}
    ## Marks the return type for an instanced save system
