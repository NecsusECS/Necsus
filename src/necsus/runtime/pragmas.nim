
template depends*(dependencies: varargs[typed]) {.pragma.}
    ## Marks that a system depends on another system

template startupSys*() {.pragma.}
    ## Marks that a system should always be added as a setup system

template teardownSys*() {.pragma.}
    ## Marks that a system should always be added as a teardown

template loopSys*() {.pragma.}
    ## Marks that a system should always be added as part of the standard loop

template saveSys*() {.pragma.}
    ## Marks that a proc generates a saved value

template restoreSys*() {.pragma.}
    ## Marks a proc that restores values from JSON

template eventSys*() {.pragma.}
    ## Marks that a system should be triggered for a specific kind of event

template instanced*() {.pragma.}
    ## Indicates that a system proc should be used as an initializer to create
    ## an instance of a system. During the primary loop, the `tick` proc is
    ## called on that instance.

template active*(states: varargs[typed]) {.pragma.}
    ## Indicates a value that must be true for a system to run