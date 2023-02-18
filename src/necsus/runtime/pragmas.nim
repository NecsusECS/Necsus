
template depends*(dependencies: varargs[typed]) {.pragma.}
    ## Marks that a system depends on another system

template startupSys*() {.pragma.}
    ## Marks that a system should always be added as a setup system

template teardownSys*() {.pragma.}
    ## Marks that a system should always be added as a teardown

template loopSys*() {.pragma.}
    ## Marks that a system should always be added as part of the standard loop

template instanced*() {.pragma.}
    ## Indicates that a system proc should be used as an initializer to create
    ## an instance of a system. During the primary loop, the `tick` proc is
    ## called on that instance.