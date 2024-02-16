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

proc isEmpty*[T](sysvar: SystemVar[T]): bool {.inline.} =
    ## Returns whether a system variable has a value
    sysvar.extract.value.isNone

proc isSome*[T](sysvar: SystemVar[T]): bool {.inline.} =
    ## Returns whether a system variable has a value
    not isEmpty(sysVar)

proc set*[T](sysvar: SystemVar[T], value: sink T) {.inline.} =
    ## Sets the value in a system variable
    sysvar.extract.value = some(value)

proc `:=`*[T](sysvar: SystemVar[T], value: sink T) {.inline.} =
    ## Sets the value in a system variable
    set(sysvar, value)

proc getOrRaise*[T](sysvar: SystemVar[T]): var T {.inline.} =
    ## Returns the value in a system variable
    sysvar.extract.value.get()

template getOrPut*[T](sysvar: SystemVar[T], build: typed): var T =
    ## Returns the value in a system variable
    if sysvar.isEmpty:
        sysvar := build
    sysvar.getOrRaise

proc getOrPut*[T](sysvar: SystemVar[T]): var T =
    ## Returns the value in a system variable
    return getOrPut(sysvar, default(T))

proc get*[T](sysvar: SystemVar[T], default: T): T {.inline.} =
    ## Returns the value in a system variable
    sysvar.extract.value.get(default)

proc get*[T](sysvar: SystemVar[T]): T {.inline.} =
    ## Returns the value in a system variable
    return sysvar.get(
        when T is string: ""
        elif T is SomeNumber: 0
        elif compiles(get(sysvar, {})): {}
        elif T is seq: @[]
        else: default(T)
    )

proc `==`*[T](sysvar: SystemVar[T], value: T): bool {.inline.} =
    ## Returns whether a sysvar is set and equals the given value
    sysvar.extract.value == some(value)

proc unwrap*[T](sysvar: SharedOrT[T] | LocalOrT[T]): T {.inline.} =
    ## Pulls a value out of a `SystemVar` or raises
    return when sysvar is T: sysvar else: sysvar.getOrRaise

proc unwrap*[T](sysvar: SharedOrT[T] | LocalOrT[T], otherwise: T): T {.inline.} =
    ## Pulls a value out of a `SystemVar` or raises
    return when sysvar is T: sysvar else: sysvar.get(otherwise)

proc `$`*[T](sysvar: SystemVar[T]): string = $sysvar.extract.value

iterator items*[T](sysvar: var SystemVar[T]): var T =
    if sysvar.isSome:
        yield sysvar.extract.value.get()

iterator items*[T](sysvar: SystemVar[T]): lent T =
    if sysvar.isSome:
        yield sysvar.extract.value.get()
