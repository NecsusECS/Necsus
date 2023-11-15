import entityId, options

type

    Delete* = proc(entityId: EntityId)
        ## Deletes an entity and all associated components

    Attach*[C: tuple] = proc(entityId: EntityId, components: C)
        ## Describes a type that is able to update existing entities new entities. Where `C` is
        ## a tuple with all the components to attach.

    Detach*[C: tuple] = proc(entityId: EntityId)
        ## Detaches a set of components from an entity. Where `C` is a tuple describing all
        ## the components to detach

    Lookup*[C: tuple] = proc(entityId: EntityId): Option[C]
        ## Looks up entity details based on its entity ID. Where `C` is a tuple with all the
        ## components to fetch

    Outbox*[T] = proc(message: sink T): void
        ## Sends an event. Where `T` is the message being sent

    TimeDelta* = float
        ## Tracks the amount of time since the last execution of a system

    TimeElapsed* = float
        ## The total amount of time spent in an app

    EntityDebug* = proc(entityId: EntityId): string
        ## Looks up an entity and returns debug data about it

    Bundle*[T: object] = ptr T
        ## A group of directives bundled together in an object

    SystemInstance* = proc(): void
        ## A callback used to invoke a specific system
