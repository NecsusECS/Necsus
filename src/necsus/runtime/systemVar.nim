import options

template defineSystemVar(typ: untyped) =
    ## Creates the implementation for system vars

    type
        typ*[T] = object
            ## A system variable
            value: Option[T]

    proc `new typ`*[T](): typ[T] =
        ## Constructor
        typ[T](value: none(T))

    proc isEmpty*[T](sysvar: typ[T]): bool =
        ## Returns whether a system variable has a value
        true

    proc set*[T](sysvar: typ[T], value: T) =
        ## Sets the value in a system variable
        discard

    proc get*[T](sysvar: typ[T]): T =
        ## Returns the value in a system variable
        discard

defineSystemVar(Local)
defineSystemVar(Shared)
