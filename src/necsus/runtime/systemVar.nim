import options

template defineSystemVar(typ: untyped) =
    ## Creates the implementation for system vars

    type
        typ*[T] {.byref.} = object
            ## A system variable
            value: Option[T]

    proc `new typ`*[T](): typ[T] =
        ## Constructor
        typ[T](value: none(T))

    proc isEmpty*[T](sysvar: typ[T]): bool {.inline.} =
        ## Returns whether a system variable has a value
        sysvar.value.isNone

    proc set*[T](sysvar: var typ[T], value: sink T) {.inline.} =
        ## Sets the value in a system variable
        sysvar.value = some(value)

    proc get*[T](sysvar: typ[T]): lent T {.inline.} =
        ## Returns the value in a system variable
        sysvar.value.get()

    proc get*[T](sysvar: typ[T], default: T): T {.inline.} =
        ## Returns the value in a system variable
        sysvar.value.get(default)

    proc `$`*[T](sysvar: typ[T]): string = $sysvar.value

defineSystemVar(Local)
defineSystemVar(Shared)
