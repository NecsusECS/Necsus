import options

type
    SystemVarData*[T] = object
        ## A system variable
        value: Option[T]

    Shared*[T] = distinct ptr SystemVarData[T]
        ## Wrapper around data that is shared across all systems

    Local*[T] = distinct ptr SystemVarData[T]
        ## Wrapper around data that is specific to a single system

    SystemVar*[T] = Shared[T] | Local[T]

proc unwrap[T](sysvar: SystemVar[T]): ptr SystemVarData[T] {.inline.} = cast[ptr SystemVarData[T]](sysvar)

proc newSystemVar*[T](): SystemVarData[T] =
    ## Constructor
    SystemVarData[T](value: none(T))

proc isEmpty*[T](sysvar: SystemVar[T]): bool {.inline.} =
    ## Returns whether a system variable has a value
    sysvar.unwrap.value.isNone

proc set*[T](sysvar: SystemVar[T], value: sink T) {.inline.} =
    ## Sets the value in a system variable
    sysvar.unwrap.value = some(value)

proc `:=`*[T](sysvar: SystemVar[T], value: sink T) {.inline.} =
    ## Sets the value in a system variable
    set(sysvar, value)

proc get*[T](sysvar: SystemVar[T]): var T {.inline.} =
    ## Returns the value in a system variable
    sysvar.unwrap.value.get()

proc get*[T](sysvar: SystemVar[T], default: T): T {.inline.} =
    ## Returns the value in a system variable
    sysvar.unwrap.value.get(default)

proc `==`*[T](sysvar: SystemVar[T], value: T): bool {.inline.} =
    ## Returns whether a sysvar is set and equals the given value
    sysvar.unwrap.value == some(value)

proc `$`*[T](sysvar: SystemVar[T]): string = $sysvar.unwrap.value
