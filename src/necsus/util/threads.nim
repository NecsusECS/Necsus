
when compileOption("threads"):
    import std/locks, atomics
    export locks, atomics

else:

    type
        Lock* = distinct int
            ## Dummy type to take the place of a lock

        Atomic*[T] = T
            ## Dummy type to represent an atomic value

        MemoryOrder* = enum
            moRelaxed
            moConsume
            moAcquire
            moRelease
            moAcquireRelease
            moSequentiallyConsistent

    template withLock*(lock: Lock, exec: untyped) =
        ## Execute a block with the given "lock" acquired
        exec

    template fetchAdd*[T](atom: var Atomic[T], add: T): T =
        ## Adds to a value and returns the new value
        let current = atom
        atom = atom + add
        current

    template store*[T](store: var Atomic[T], value: T) =
        ## Stores a value
        store = value

    template load*[T](store: Atomic[T], order: MemoryOrder = moRelaxed): T =
        ## Stores a value
        store

    template atomicInc*[T](atom: var Atomic[T], add: T) =
        ## Increments a value
        atom = atom + add

    template atomicDec*[T](atom: var Atomic[T], dec: T) =
        ## Increments a value
        atom = atom - dec

    proc compareExchange*[T](
        atom: var Atomic[T],
        expected,
        value: T,
        success: MemoryOrder = moRelaxed,
        failure: MemoryOrder = moRelaxed
    ): bool {.inline.} =
        ## Adds to a value and returns the new value
        result = atom == expected
        if result:
            atom = value

    template fence*(order: MemoryOrder) =
        discard