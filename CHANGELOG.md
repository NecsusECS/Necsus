# Changelog

## 0.11.0

### Bug Fixes

* Fix inbox sharing when a system is assigned to a variable
* Fix inbox name collisions when argument names were the same
* Fix error messages when a system incorrectly returns a value
* Fix invalid code dumping when a newline is injected after a sink parameter
* Allow joined tuples to operated on joined tuples

### Backwards incompatible changes

* Use `()` operator for directives instead of passing in procs. This improves compile speed
  and performance by removing the need for Nim to create and manage closures. However, it
  requires that all Necsus users enable the `--experimental:callOperator` flag.
* Remove the `necsusFloat32` flag and instead use `BiggestUInt` and `BiggestFloat`

### New Features

* Accessory components
   * Adding the `accessory` pragma means that a component no longer forces the creation
     of new archetypes. This reduces the size of generated code and improves compile speed.
* Adds `SystemVar.clear`
* Support tuple joining without explicit type definitions
* Add an error message when attach/detach/swap fails
* Build speed improvements
* Adds `SaveSystemInstance` and `EventSystemInstance` types
* Fast compile mode for speeding up IDE integration

## 0.10.0

### Bug Fixes

* Fix memory corruption bug caused by Nim mishandling sink parameters
* Support tuples in `Shared` and `Local`
* Fix a bug where an instanced `eventSys` can't be invoked

### New Features

* Add compiler flags for tracing various behavior during execution
    * `-d:necsusSaveTrace` -- Log save and restore activity
    * `-d:necsusQueryTrace` -- Log executed queries
    * `-d:necsusEventTrace` -- Log when an event is sent
    * `-d:necsusEntityTrace` -- Log when entities are created, modified or deleted
* Overall reduction of memory allocations

### Backwards incompatible changes

* Mark the logger parameter as `gcsafe` and `raises: []`
* Remove the `sink` flag from the `Outbox` proc parameter

## 0.9.1

### Bug Fixes

* Fix `Lookup` directives that contain a `Not` clause

## 0.9.0

### Breaking Changes

No known breaking changes

### New Features

* `extend` and `join` macros for combining tuple types
* `eventSys` system type
* Include `import` statements when using `-d:dump`
* Support for `Optional` components in `Detach` directives
* Add the `Swap` directive
* Add the `-d:archetypes` build flag
* Support component aliases with generics
* `Save` and `Restore` directives, along with `saveSys` and `restoreSys` system types
* Returning `SystemInstance` automatically flags a system as instanced.

### Other Changes

* Ensure that archetype rows are never copied
* Silence noisy compiler warnings
* Reduce size of generated code by around 50%
* Logger is disabled by default

## 0.8.0

### New Features

* Add the `-d:necsusLog` compiler flag for logging when systems are called
* Support for the `-d:necsusFloat32` compiler flag to ensure float32 values are used internally
* Add a variant of  `SystemVar.getOrPut` that sets default values
* Support sending events in from the outside world when an app instance is self-managed

### Breaking Changes

* Removed the `eventQueueSize` parameter from `newNecsusConf` as it is now unused. Event queues are dynamically sized.
* Use a `uint32` for tick IDs

### Other Changes

* Support for `ref` types in system variables
* Removed code gen elision for nimsuggest as it was causing language server errors
* Remove unnecessary initializers in generated code
* Hosting of the readme directly on the doc site: https://necsusecs.github.io/Necsus/

## 0.7.0

### Breaking Changes

1. Removed `teardown` and `startup` parameters from the `necsus` pragma. With this change, you should switch to using the `startupSys` and `teardownSys` pragmas attached directly to the systems instead. For example, this:

   ```nim
   import necsus
   proc startupSystem() = discard
   proc loopSystem() = discard
   proc teardownSys() = discard

   proc app() {.necsus([~startupSys], [~loopSys], [~teardownSys], newNecsusConf).}
   ```

   would become:

   ```nim
   import necsus
   proc startupSystem() {.startupSys.} = discard
   proc loopSystem() = discard
   proc teardownSys() {.teardownSys.} = discard

   proc app() {.necsus([~startupSys, ~loopSys, ~teardownSys], newNecsusConf).}
   ```
2. `Spawn` and `Query` no longer return an `EntityId`. If you need them, use a `FullSpawn` or a `FullQuery` instead. This change allows Necsus to improve build speeds and produce less output code. If you're interested in the details, read on.

   During a build, Necsus automatically generates a set of all possible archetypes that could possibly exist at runtime. It does this by examining systems with `FullQuery`, `FullSpawn`, `Lookup`, and `Attach` directives, then uses that to calculate all the combinatorial possibilities. Naively, this is an exponential algorithm. This is important because archetypes themselves aren't free. Each archetype that exists increases build times and slows down queries.

   Using `Spawn` instead of `FullSpawn` and `Query` instead of `FullQuery` allows the underlying algorithm to ignore those specific directives when calculating the final set of archetypes. Because your system doesn't have access to the `EntityId`, it can't use the output of a `Spawn` call as the input to an Attach directive, which means it can't contribute to the list of archetypes.
3. Convert `TimeDelta` and `TimeElapsed` from `float` to `proc(): float`. This means anywhere you were referencing it as a variable, you now need to invoke it as a proc. This was done to make sure any times stored in a `Bundle` return correct values.

### New Features

1. Add the `runSystemOnce` macro. This makes it easier to test a system. This macro accepts a single lambda as an argument, and will invoke that lambda as if it were a system. You can then pass those directives to other systems, or interact with them directly.
2. Add a new directive, `TickId`. `TickId` gives you an auto-incrementing ID for each time a tick is executed. This is useful, for example, if you need to track whether an operation has already been performed for the current tick.
3. Add support for the `-d:profile` compiler flag. This allows you to get a quick and dirty idea of how your app is performing. When this flag is set, Necsus will add profiling code that reports how long each system is taking. It takes measurements, then outputs the timings to the console.

### Other Changes

1. Allow `Inbox`es to work in a `Bundle`
2. Improve the code generated by `-d:dump` so it can be directly copied and pasted without change
3. Lazy archetype instantiation. This means that memory will only be allocated once an archetype is actually used
5. Use fewer closures when defining an app
6. Speed up archetype generation code by using a bitset instead of a full `Set`
7. Fix `Bundle`s that use generics
8. Code gen an iterator for each query instead of using runtime generics
9. Various bug fixes
10. Various code-gen speed improvements

## 0.6.0

### Breaking changes

#### Require archetype definitions to be sorted

This was done to simplify macro logic, which led to compile time performance improvvments.

#### Per system inboxes.

This fixes an unintuitive situation where an inbox appears in the system list before the outbox. In that case, events are sent, but never received because all the mailboxes were cleared at the end of every tick.

With this change, each system gets its own inbox, which is cleared after the system executes. It will mean more memory usage, but the difference should be small. And the behavior will be much more intuitive.

### New Features

* Add state management via the `active` pragma. See readme for details
* Add `SysVar.getOrPut`
* Add `Shared.isSome`
* Add `Inbox.len`
* `Bundle` pragma. See readme for details

### Other changes of note

* Many compile time speed improvements
* Various bug fixes
* Improved generic alias handling
