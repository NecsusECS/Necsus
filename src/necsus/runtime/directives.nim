import entity, options

type

    Spawn*[C: tuple] = proc(components: sink C): EntityId
        ## Describes a type that is able to create new entities

    Delete* = proc(entityId: EntityId)
        ## Deletes an entity

    Attach*[C: tuple] = proc(entityId: EntityId, components: C)
        ## Describes a type that is able to update existing entities new entities

    Detach*[C: tuple] = proc(entityId: EntityId)
        ## Detaches a set of components from an entity

    Lookup*[C: tuple] = proc(entityId: EntityId): Option[C]
        ## Looks up entity details based on its entity ID

    Outbox*[T] = proc(message: sink T): void
        ## Sends an event

    TimeDelta* = float
        ## Tracks the amount of time since the last execution of a system

    TimeElapsed* = float
        ## The total amount of time spent in an app
