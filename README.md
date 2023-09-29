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
        discard spawn.with(
            Position(x: rand(0.0..100.0), y: rand(0.0..100.0)),
            Velocity(dx: rand(0.0..10.0), dy: rand(0.0..10.0))
        )

proc move(dt: TimeDelta, entities: Query[(ptr Position, Velocity)]) =
    ## Updates the positions of each component
    for (position, velocity) in entities:
        position.x += dt * velocity.dx
        position.y += dt * velocity.dy

proc report(entities: Query[(Position, )]) =
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
    discard create.with("foo")
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
    discard create.with("foo")
    result.query = query

proc tick(system: var SystemInstance) =
    for (str,) in system.query:
        echo str

proc `=destroy`(system: var SystemInstance) =
    echo "Destroying system"

proc myApp() {.necsus([], [~someSystem], [], newNecsusConf()).}
```

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

```nim
import necsus

type
    A = object
    B = object

proc spawningSystem(spawn: Spawn[(A, B)]) =
    for i in 1..10:
        let spawnedEntityId = spawn.with(A(), B())
        echo "Spawned a new entity with ID: ", spawnedEntityId

proc myApp() {.necsus([~spawningSystem], [], [], newNecsusConf()).}
```

#### Query

Queries allow you to iterate over entities that have a specific set of components attached to them. Queries are the
primary mechanism for interacting with entities and components.

```nim
import necsus

type
    A = object
    B = object

proc queryingSystem(query: Query[(A, B)]) =
    for eid, components in query:
        echo "Found entity ", eid, " with ", components[0], " and ", components[1]

proc myApp() {.necsus([], [~queryingSystem], [], newNecsusConf()).}
```

#### Queries with Pointers

If you want to loop through a set of entities and update the values of their components, the most efficient
mechanism available is to update those values in place. This is accomplished by requested pointers when doing a query:

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

There will be times you want to query for entities that contain a set of entities, but also exclude another set of
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

proc deletingSystem(query: Query[(A, B)], delete: Delete) =
    for eid, _ in query:
        delete(eid)

proc myApp() {.necsus([], [~deletingSystem], [], newNecsusConf()).}
```

#### Lookup

Lookup allows you to get components for an entity when you already have the entity id. It returns an `Option`, which
will be a `Some` if the entity has the exact requested components:

```nim
import necsus, options

type
    A = object
    B = object
    C = object
    D = object

proc lookupSystem(query: Query[(A, B)], lookup: Lookup[(C, D)]) =
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

proc attachDetach(query: Query[(A, )], attachB: Attach[(B, )], detachC: Detach[(C, )]) =
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
````

## Debugging an Entity

When you find yourelf in a position that you need to see the exact state that an entity is in, you can get a string
dump of that entity by using the `EntityDebug` directive:

```nim
import necsus

type
    A = object

proc debuggingSystem(query: Query[(A, )], debug: EntityDebug) =
    for eid, _ in query:
        echo debug(eid)

proc myApp() {.necsus([], [~debuggingSystem], [], newNecsusConf()).}
```

## Debugging Generated Code

If Necsus isn't behaving as you would expect, the best tool you've got in your toolbox is the ability to dump the code
that it generates. This allows you to walk through what is happening, or even substitute the generated code into your
app and execute it. This can be enabled by compiling with the `-d:dump` flag set.

# License

Code released under the [Apache 2.0 license](https://github.com/NecsusECS/Necsus/blob/main/LICENSE)
