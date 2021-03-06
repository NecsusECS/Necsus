import entityId, options

type

    Spawn*[C: tuple] = proc(components: sink C): EntityId
        ## Describes a type that is able to create new entities. Where `C` is a tuple
        ## with all the components to initially attach to this entity

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
