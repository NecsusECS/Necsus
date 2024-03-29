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

    Lookup*[C: tuple] = proc(entityId: EntityId): Option[C] {.gcsafe, raises: [].}
        ## Looks up entity details based on its entity ID. Where `C` is a tuple with all the
        ## components to fetch

    Outbox*[T] = proc(message: sink T): void
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
