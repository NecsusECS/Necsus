import options

type
    SystemVarData*[T] = object
        ## A system variable
        value: Option[T]

    Shared*[T] = distinct ptr SystemVarData[T]
        ## Wrapper around data that is shared across all systems

    SharedOrT*[T] = Shared[T] | T
        ## A shared value or the value itself

    Local*[T] = distinct ptr SystemVarData[T]
        ## Wrapper around data that is specific to a single system

    LocalOrT*[T] = Local[T] | T
        ## A local value or the value itself

    SystemVar*[T] = Shared[T] | Local[T]

proc extract[T](sysvar: SystemVar[T]): ptr SystemVarData[T] {.inline.} = cast[ptr SystemVarData[T]](sysvar)

proc newSystemVar*[T](): SystemVarData[T] =
    ## Constructor
    SystemVarData[T](value: none(T))

proc isEmpty*[T](sysvar: SystemVar[T]): bool {.inline.} =
    ## Returns whether a system variable has a value
    sysvar.extract.value.isNone

proc set*[T](sysvar: SystemVar[T], value: sink T) {.inline.} =
    ## Sets the value in a system variable
    sysvar.extract.value = some(value)

proc `:=`*[T](sysvar: SystemVar[T], value: sink T) {.inline.} =
    ## Sets the value in a system variable
    set(sysvar, value)

proc getOrRaise*[T](sysvar: SystemVar[T]): var T {.inline.} =
    ## Returns the value in a system variable
    sysvar.extract.value.get()

proc get*[T](sysvar: SystemVar[T], default: T): T {.inline.} =
    ## Returns the value in a system variable
    sysvar.extract.value.get(default)

proc get*[T](sysvar: SystemVar[T]): T {.inline.} =
    ## Returns the value in a system variable
    when T is string:
        return get(sysvar, "")
    elif compiles(get(sysvar, {})):
        return get(sysvar, {})
    else:
        return get(sysvar, low(T))

proc `==`*[T](sysvar: SystemVar[T], value: T): bool {.inline.} =
    ## Returns whether a sysvar is set and equals the given value
    sysvar.extract.value == some(value)

proc unwrap*[T](sysvar: SharedOrT[T] | LocalOrT[T]): T {.inline.} =
    ## Pulls a value out of a `SystemVar` or raises
    return when sysvar is T: sysvar else: sysvar.getOrRaise

proc `$`*[T](sysvar: SystemVar[T]): string = $sysvar.extract.value
