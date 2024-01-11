# Necsus

[![Build](https://github.com/NecsusECS/Necsus/actions/workflows/build.yml/badge.svg)](https://github.com/NecsusECS/Necsus/actions/workflows/build.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://github.com/NecsusECS/Necsus/blob/main/LICENSE)

![](https://github.com/NecsusECS/NecsusParticleDemo/blob/main/demo.gif?raw=true)


A "disappearing" ECS (entity component system) library for Nim. Necsus uses Nim macros to generate code for creating
and executing an ECS based application. Components are just regular objects, systems are regular procs, and everything
related to entities is handled for you.

More details about how ECS architectures work can be found here:

* [Component game programming pattern](http://gameprogrammingpatterns.com/component.html)
* [What's an Entity System?](http://entity-systems.wikidot.com/)
* [Evolve your hierarchy](https://cowboyprogramming.com/2007/01/05/evolve-your-heirachy/)
* [ECS on wikipedia](https://en.wikipedia.org/wiki/Entity_component_system)

### Design

Necsus was born out of the idea that Nim's macros could drastically reduce the boilerplate required for building an ECS
based application, while still being approachable and keeping the cognitive overhead low.

* Entities are managed on your behalf. Under the covers, they're represented as an `int32`
* Components are regular Nim types. Just about any type can be be used as a component.
* Systems are `proc`s. They get access to the broader application state through arguments with special types; called
  directives
* Systems and components are wired together automatically into a `proc` called an "app". Running your app is as simple
  as calling the genereated `proc`.

### An example

```nim
import necsus, random

type
    Position = object
        x*, y*: float

    Velocity = object
        dx*, dy*: float

proc create(spawn: Spawn[(Position, Velocity)]) =
    ## Creates a handful entities at random positions with random velocities
    for _ in 1..10:
        spawn.with(
            Position(x: rand(0.0..100.0), y: rand(0.0..100.0)),
            Velocity(dx: rand(0.0..10.0), dy: rand(0.0..10.0))
        )

proc move(dt: TimeDelta, entities: Query[(ptr Position, Velocity)]) =
    ## Updates the positions of each component
    for (position, velocity) in entities:
        position.x += dt * velocity.dx
        position.y += dt * velocity.dy

proc report(entities: FullQuery[(Position, )]) =
    ## Prints the position of each entity
    for eid, comp in entities:
        echo eid, " is at ", comp[0]

proc exiter(iterations: Local[int], exit: Shared[NecsusRun]) =
    ## Keeps track of the number of iterations through the system and eventually exits
    if iterations.get(0) >= 100:
        exit := ExitLoop
    else:
        iterations := iterations.get(0) + 1

proc app() {.necsus([~create], [~move, ~report, ~exiter], [], newNecsusConf()).}
    ## The skeleton into which the ECS code will be injected

# Run your app
app()
```

### More Examples

* [Particle Demo](https://github.com/NecsusECS/NecsusParticleDemo)
* [Asteroids](https://github.com/NecsusECS/NecsusAsteroids)

## API Documentation

API Documentation is available here:

https://necsusecs.github.io/Necsus/

## Using Necsus

To get started with Necsus, you define your app by adding the `necsus` pragma onto a function declaration:

```nim
import necsus

proc myApp() {.necsus([], [], [], newNecsusConf()).}
```

That's it. At this point you have a functioning ECS setup, though it won't do much without systems attached. If you
were to call `myApp` it would just loop infinitely.

### Adding systems

To make your application do useful work, you need to wire up systems. Creating a system is easy -- it's just a `proc`.
The name of that `proc` then prefixed with a `~` and passed into the `necsus` pragma:

```nim
import necsus

proc helloWorld() =
    echo "hello world"

proc myApp() {.necsus([], [~helloWorld], [], newNecsusConf()).}
```

In the above example, if you called `myApp`, it would print `hello world` to the console in an infinite loop.

If you're curious about the tilde prefix, it's used to convince the Nim type checker that all the give systems
are actually compatible, despite being `proc`s with different arguments.

### Passing multiple systems

When given multiple systems, they will be executed in the same order in which they are passed in:

```nim
import necsus

proc first() =
    discard

proc second() =
    discard

proc myApp() {.necsus([], [~first, ~second], [], newNecsusConf()).}
```

### Types of Systems

Within the lifecycle of an app, there are three phases in which a system can be registered:

1. Startup: The system is executed once when the app is started
2. Loop: The system is executed for every loop
3. Teardown: The system is executed once after the loop exits

```nim
import necsus

proc startupSystem() =
    discard

proc loopSystem() =
    discard

proc teardownSystem() =
    discard

proc myApp(input: string) {.necsus(
    startup = [~startupSystem],
    systems = [~loopSystem],
    teardown = [~teardownSystem],
    conf = newNecsusConf()
).}
```

#### Dependencies between systems

A system may require that another system always be paired with it. This can be accomplished by adding the  `depends`
pragma, which declares that relationship:

```nim
import necsus

proc runFirst() =
    ## No-op system, but it gets run first
    discard

proc runSecond() {.depends(runFirst).} =
    ## No-op system that gets run second
    discard

proc myApp() {.necsus([], [~runSecond], [], newNecsusConf()).}
```

#### Marking systems for explicit phases

If you have a system that should always be run during a specific phase, you can explicitly mark it with a phase
pragma to ensure that it is always added where you expect it to be added. This is particularly useful when
paired with dependencies, as it allows you to depend on setup or teardown phases. It can also be used to enforce
the order of execution for a phase.

```nim
import necsus

proc startupSystem() {.startupSys.}=
    discard

proc loopSystem() {.loopSys.} =
    discard

proc teardownSystem() {.teardownSys} =
    discard

proc myApp() {.necsus([], [~startupSystem, ~loopSystem, ~teardownSystem], [], newNecsusConf()).}
```

#### Instancing systems

For systems that need to maintain state, it can be convenient to hold on to an instance between invocations. The
first step to setting is up is to mark a system with the `instanced` pragma. Then, you've got two options:

**Option 1: Return a Proc**

If your system returns a `proc`, that proc will get created during the startup phase, then invoked
for every tick. The `proc` itself that gets returned here cannot take any arguments. For example:

```nim
import necsus

proc someSystem(create: Spawn[(string, )], query: Query[(string,)]): auto {.instanced.} =
    create.with("foo")
    return proc() =
        for (str,) in query:
            echo str

proc myApp() {.necsus([], [~someSystem], [], newNecsusConf()).}
```

Obviously, this makes it easier to capture the pragmas from your parent system as closure variables,
which can then be freely used.

**Option 2: Return an Object**

Your other option is to return an object. The system proc will get invoked during the startup phase,
then a `tick` proc will get invoked as part of the main loop. This also allows you to create a `=destroy`
proc that gets invoked during teardown:

```nim
import necsus

type SystemInstance = object
    query: Query[(string,)]

proc someSystem(create: Spawn[(string, )], query: Query[(string,)]): SystemInstance {.instanced.} =
    create.with("foo")
    result.query = query

proc tick(system: var SystemInstance) =
    for (str,) in system.query:
        echo str

proc `=destroy`(system: var SystemInstance) =
    echo "Destroying system"

proc myApp() {.necsus([], [~someSystem], [], newNecsusConf()).}
```

### Building Re-usable systems

Reusing code is obviously a fundamental aspect of programming, and using generics is a fundamental aspect of
that in Nim. Necsus, however, can't resolve generic parameters by itself. It needs to know exactly what components
need to be passed to each system at compile time.

To work around this, you can assign systems to variables, then pass those variables into your app:

```nim
import necsus

type
    SomeComponent = object
    AnotherComponent = object

proc genericSpawner[T](): auto =
    return proc (create: Spawn[(T, )]) =
        create.with(T())

let spawnSomeComponent = genericSpawner[SomeComponent]()
let spawnAnotherComponent = genericSpawner[AnotherComponent]()

proc myApp() {.necsus([], [~spawnSomeComponent, ~spawnAnotherComponent], [], newNecsusConf()).}
```

It's worth mentioning that if you start usin type aliases, Nim's type system has a tendency to hide those
from the macro system -- they generally get resolved directly down to the type they are aliasing. To work around that,
you can add in explicit type declarations.

### Exiting

Exiting the primary system loop is done through a `Shared` directive. Directives will be covered in more details below,
but all you need to know in this case is that it's sending a signal to the loop executor by changing a bit of shared
state:

```nim
import necsus

proc immediateExit(exit: Shared[NecsusRun]) =
    ## Immediately exit the first time this system is called
    exit.set(ExitLoop)

proc myApp() {.necsus([], [~immediateExit], [], newNecsusConf()).}

myApp()
```

### Directives

Systems interact with the rest of an app by using special method arguments, called `Directives`. These directives are
just regular types that Necsus knows how to wire up in special ways.

Systems can't have any other type of argument. If Necsus doesn't recognize how to wire-up an argument, the compile
will fail.

#### Spawn

To create new entities, use a `Spawn` directive. This takes a single argument, which is the initial set of components
to attach to the newly minted entity.

There are two ways to spawn an entity, `Spawn` and `FullSpawn`. Under the covers, they do the same thing. The difference
is that `FullSpawn` returns the generated `EntityId`, and `Spawn` does not. In general, you should use `Spawn` over
`FullSpawn` whenever possible.

```nim
import necsus

type
    A = object
    B = object

proc spawningSystem(spawn: Spawn[(A, B)]) =
    for i in 1..10:
        spawn.with(A(), B())
        echo "Spawned a new entity!"

proc myApp() {.necsus([~spawningSystem], [], [], newNecsusConf()).}
```

##### Why `Spawn` and `FullSpawn`?

During a build, Necsus automatically generates a set of all possible archetypes that could possibly exist at
runtime. It does this by examining systems with `FullQuery`, `FullSpawn`, `Lookup`, and `Attach` directives then uses
that to calculate all the combinatorial possibilities. Naively, this is an exponential algorithm. This is important
because archetypes themselves aren't free. Each archetype that exists increases build times and slows down queries.

Using `Spawn` instead of `FullSpawn` allows the underlying algorithm to ignore those directives when calculating the
final set of archetypes. Because your system doesn't have access to the `EntityId`, it can't use the output of a
`Spawn` call as the input to an `Attach` directive, which means it can't contribute to the list of archetypes.

#### Query and FullQuery

Queries allow you to iterate over entities that have a specific set of components attached to them. Queries are the
primary mechanism for interacting with entities and components.

There are two kinds of queries, `Query` and `FullQuery`. `Query` gives you access to the components, while `FullQuery`
gives you access to the components _and_ the `EntityId`. You should use `Query` wherever possible, then only use
`FullQuery` when you explicitly need the `EntityId`. For details about why the two mechanisms exist, see the section
above about `Spawn` versus `FullSpawn`.

```nim
import necsus

type
    A = object
    B = object

proc reportingSystem(query: Query[(A, B)]) =
    for components in query:
        echo "Found entity with ", components[0], " and ", components[1]

proc reportingSystemWithEntity(query: FullQuery[(A, B)]) =
    for eid, components in query:
        echo "Found entity ", eid, " with ", components[0], " and ", components[1]

proc myApp() {.necsus([], [~reportingSystem, ~reportingSystemWithEntity], [], newNecsusConf()).}
```

#### Queries with Pointers

If you want to loop through a set of entities and update the values of their components, the most efficient
mechanism available is to update those values in place. This is accomplished by requesting pointers when doing a query:

```nim
import necsus

type
    A = object
        value: int

proc inPlaceUpdate(query: Query[(ptr A, )]) =
    for (a) in query:
        a.value += 1

proc myApp() {.necsus([], [~inPlaceUpdate], [], newNecsusConf()).}
```

#### Queries that exclude components

There will be times you want to query for entities that _exclude_ a set of
components. This can be accomplished with the `Not` type:

```nim
import necsus

type
    A = object
        a: string
    B = object
        b: string
    C = object

proc excludingC(query: Query[(A, B, Not[C])]) =
    for (a, b, _) in query:
        echo "Found a with ", a.a, " and b with ", b.b

proc myApp() {.necsus([], [~excludingC], [], newNecsusConf()).}
```

#### Queries with optional components

If you would like a query to include a component if it exists, but still return the entity if it doesn't exist, you
can use an optional in the component query:

```nim
import necsus, options

type
    A = object
        a: string
    B = object
        b: string

proc optionalB(query: Query[(A, Option[B])]) =
    for (a, b) in query:
        echo "Found a with ", a.a
        if b.isSome: echo "Component B exists: ", b.get().b

proc myApp() {.necsus([], [~optionalB], [], newNecsusConf()).}
```

### Query for a single value

For situations where you have a singleton instance, you can use the `single` method to pull it from a query:

```nim
import necsus, options

type A = object

proc oneInstance(query: Query[(A, )]) =
    let (a) = query.single.get
    echo a

proc myApp() {.necsus([], [~oneInstance], [], newNecsusConf()).}
```

#### Delete

Deleting is the opposite of spawning -- it deletes an entity and all the associated components:

```nim
import necsus

type
    A = object
    B = object

proc deletingSystem(query: FullQuery[(A, B)], delete: Delete) =
    for eid, _ in query:
        delete(eid)

proc myApp() {.necsus([], [~deletingSystem], [], newNecsusConf()).}
```

#### Lookup

`Lookup` allows you to get components for an entity when you already have the entity id. It returns an `Option`, which
will be a `Some` if the entity has the exact requested components:

```nim
import necsus, options

type
    A = object
    B = object
    C = object
    D = object

proc lookupSystem(query: FullQuery[(A, B)], lookup: Lookup[(C, D)]) =
    for eid, _ in query:
        let (c, d) = lookup(eid).get()
        echo "Found entity ", eid, " with ", c, " and ", d

proc myApp() {.necsus([], [~lookupSystem], [], newNecsusConf()).}
```

#### Attach/Detach

Attaching and detaching allow you to add new components or remove existing components from an entity:

```nim
import necsus, options

type
    A = object
    B = object
    C = object

proc attachDetach(query: FullQuery[(A, )], attachB: Attach[(B, )], detachC: Detach[(C, )]) =
    for eid, _ in query:
        eid.attachB((B(), ))
        eid.detachC()

proc myApp() {.necsus([], [~attachDetach], [], newNecsusConf()).}
```

#### TimeDelta

`TimeDelta` is a `float` filled with the amount of time since the last execution of a system

```nim
import necsus

proc showTime(dt: TimeDelta) =
    echo "Time since last system execution: ", dt

proc myApp() {.necsus([], [~showTime], [], newNecsusConf()).}
```

#### TimeElapsed

`TimeElapsed` is a `float` that tracks the amount of time spent executing the current application

```nim
import necsus

proc showTime(elapsed: TimeElapsed) =
    echo "Time spent executing app: ", elapsed

proc myApp() {.necsus([], [~showTime], [], newNecsusConf()).}
```

#### Local

Local variables are a way to manage state that is specific to one system. Local variables will only be visible to the
system that declares them as arguments.

```nim
import necsus

proc localVars(executionCount: Local[int]) =
    echo "Total executions so far: ", executionCount.get(0)
    executionCount := executionCount.get(0) + 1

proc myApp() {.necsus([], [~localVars], [], newNecsusConf()).}
```

#### Shared

Shared variables are shared across all systems. Any shared variable with the same type will have access to the same
underlying value.

```nim
import necsus

proc updateCount(count: Shared[int]) =
    count := count.get(0) + 1

proc printCount(count: Shared[int]) =
    echo "Total executions so far: ", count.get(0)

proc myApp() {.necsus([], [~updateCount, ~printCount], [], newNecsusConf()).}
```

#### Inbox/Outbox (aka Events)

`Inbox` and `Outbox` represent the eventing system in Necsus. Events are published using the `Outbox` and read using
the `Inbox`. Any `Inbox` or `Outbox` with the same type will shared the same underlying mailbox.

```nim
import necsus

type SomeEvent = distinct string

proc publish(sender: Outbox[SomeEvent]) =
    sender(SomeEvent("This is a message"))

proc receive(receiver: Inbox[SomeEvent]) =
    for event in receiver:
        echo event.string

proc myApp() {.necsus([], [~publish, ~receive], [], newNecsusConf()).}
```

#### Bundles

`Bundle`s are a way of grouping together multiple directives into a single object to make them easier pass around. They
are useful when you want to encapsulate a set of logic that needs to operate on multiple directives.

```nim
import necsus

type
    A = object

    B = object

    MyBundle = object
        spawn*: FullSpawn[(A, )]
        attach*: Attach[(B, )]

proc useBundle(bundle: Bundle[MyBundle]) =
    let eid = bundle.spawn.with(A())
    bundle.attach(eid, (B(), ))

proc myApp() {.necsus([], [~useBundle], [], newNecsusConf()).}
```

#### TickId

`TickId` gives you an auto-incrementing ID for each time a `tick` is executed. This is useful, for example, if you need
to track whether an operation has already been performed for the current tick.

```nim
import necsus

proc printTickId(tickId: TickId) =
    echo "Current tick ID is ", tickId()

proc myApp() {.necsus([], [~printTickId], [], newNecsusConf()).}
```

### App

At an app level, there are a few more features worth discussing.

#### App Arguments

Any arguments passed in to your app will be available as `Shared` arguments to your systems:

```nim
import necsus

proc exampleSystem(input: Shared[string]) =
    echo input.get()

proc myApp(input: string) {.necsus([], [~exampleSystem], [], newNecsusConf()).}
```

#### App Return Type

If an app has a return value, it can be set in a system via a `Shared` argument:

```nim
import necsus

proc setAppReturn(appReturns: Shared[string]) =
    appReturns.set("Return value from app")

proc myApp(): string {.necsus([], [~setAppReturn], [], newNecsusConf()).}
```

#### App Configuration

Runtime configuration for the execution environment can be controlled through the `newNecsusConf()` call passed to the
`necsus` pragma. For example, the number of entities to reserve at startup can be configured as follows:

```nim
import necsus

proc myApp() {.necsus([], [], [], newNecsusConf(entitySize = 100_000)).}
```

#### Custom runners

The `runner` is the function that is used to execute the primary system loop. The default runner is fairly simple -- it
executes the loop systems repeatedly until the Shared `NecsusRun` variable flips over to `ExitLoop`. If you need more
control over your game loop, you can pass in your own.

The last argument for a custom runner must be the `tick` callback. Any other arguments will be processed in the same
manner as a system. This allows your runner to access entities, shared values or events.

```nim
import necsus

proc customRunner*(count: Shared[int], tick: proc(): void) =
    # Loop until 1000 iterations completed
    while count.get(0) < 1_000:
        tick()

proc incrementer(count: Shared[int]) =
    count.set(count.get(0) + 1)

proc myApp() {.necsus(customRunner, [], [~incrementer], [], newNecsusConf()).}

myApp()
```

#### Don't call me, I'll call you

There are situations where you may not want Necsus to be in charge of executing the loop. For example, if you are
integrating with an SDK that uses a callback mechanism for controlling the main game loop. For those situations,
you can manually initialize your app and invoke the `tick` function that Necsus generates:

```nim
import necsus

proc myExampleSystem() =
    discard

proc myApp() {.necsus([], [~myExampleSystem], [], newNecsusConf()).}

# Initialize the app and execute the main loop 3 times
var app = initMyApp()
app.tick()
app.tick()
app.tick()
```

## Debugging an Entity

When you find yourelf in a position that you need to see the exact state that an entity is in, you can get a string
dump of that entity by using the `EntityDebug` directive:

```nim
import necsus

type
    A = object

proc debuggingSystem(query: FullQuery[(A, )], debug: EntityDebug) =
    for eid, _ in query:
        echo debug(eid)

proc myApp() {.necsus([], [~debuggingSystem], [], newNecsusConf()).}
```

## Game State Management

Often times, games will have various states they can be in at a high level.  For example, your game may have states to
represent "loading", "playing", "won" or "lost". For this, you can annotate a system with the `active` pragma so it
only executes when the game is in a specific state. `Shared` directives are then used for changing between states.

```nim
import necsus

type GameState = enum Loading, Playing, Won, Lost

proc showWon() {.active(Won).} =
    echo "Game won!"

proc switchGameState(state: Shared[GameState]) =
    ## System that changes the game state to "won"
    state := Won

proc myApp() {.necsus([], [~showWon, ~switchGameState], [], newNecsusConf()).}
```

### Listening to state changes

When you have an action that needs to be executed once when a state changes, you can encapsulate your state changes
into a `Bundle`, then publish an event into an `Outbox`. For example, imagine a project layed out in a few files
like this:

```nim
##
## gameState.nim
##

import necsus

type
    GameState* = enum Loading, Playing, Won, Lost

    StateManager* = object
        state: Shared[GameState]
        stateChange: Outbox[GameState]

proc change*(manager: Bundle[StateManager], newState: GameState) =
    ## Central entry point when then game state needs to be changed
    manager.state := newState
    manager.stateChange(newState)

##
## customSystem.nim
##

proc customSystem*(stateChanges: Inbox[GameState]) =
    for newState in stateChanges:
        echo "State changed to ", newState

##
## changeStateSystem.nim
##

proc changeStateSystem(manager: Bundle[StateManager], winConditionMet: Shared[bool]) =
    if winConditionMet.get(false):
        manager.change(Won)

##
## app.nim
##

proc app() {.necsus([], [~customSystem, ~changeStateSystem], [], newNecsusConf()).}
```

## Testing Systems

To test a system, you can use the `runSystemOnce` macro. It accepts a single lambda as an
argument, and will invoke that lambda as if it were a system. You can then pass those
directives to other systems, or interact with them directly.

```nim
import unittest, necsus

proc myExampleSystem(str: Shared[string]) =
    str := "foo"

runSystemOnce do (str: Shared[string]) -> void:
    test "Execute myExampleSystem":
        myExampleSystem(str)
        check(str.get == "foo")
```

## Profiling systems

To get a quick and dirty idea of how your app is performing, you can compile with the `-d:profile` flag set. This
will cause Necsus to add profiling code that will report how long each system is taking. It takes measurements,
then outputs the timings to the console.

## Debugging Generated Code

If Necsus isn't behaving as you would expect, the best tool you've got in your toolbox is the ability to dump the code
that it generates. This allows you to walk through what is happening, or even substitute the generated code into your
app and execute it. This can be enabled by compiling with the `-d:dump` flag set.

# License

Code released under the [Apache 2.0 license](https://github.com/NecsusECS/Necsus/blob/main/LICENSE)
