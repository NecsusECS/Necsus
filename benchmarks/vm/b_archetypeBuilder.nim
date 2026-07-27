## A compile time (VM) benchmark for `ArchetypeBuilder.build`
##
## Large Necsus apps spend the bulk of their compilation inside the archetype graph
## calculation. This benchmark drives `ArchetypeBuilder` directly with a synthesized
## workload that has the same shape as a real game -- a pile of spawned entity kinds,
## plus filtered attach/detach actions that combinatorially expand them -- without
## paying for macro expansion, C code gen or linking.
##
## All the work happens while compiling, so the numbers to watch are the compiler's, not
## the produced binary's. `nim check` runs the VM without paying for code gen:
##
##     nimble vmbenchmark
##     nim check --profileVM benchmarks/vm/b_archetypeBuilder.nim
##
## The knobs below scale the workload. `-d:archScale=N` grows it roughly linearly by
## adding more entity shapes; every count can also be overridden on its own to isolate
## what a change is sensitive to:
##
##     nim check --profileVM -d:archScale=4 benchmarks/vm/b_archetypeBuilder.nim
##     nim check --profileVM -d:archAttaches=11 benchmarks/vm/b_archetypeBuilder.nim
##
## The archetype count is echoed at compile time. It is a pure function of the knobs,
## so any optimization that changes it has changed behavior.

import necsus/compiletime/archetypeBuilder, std/[sequtils, sets, tables, random]

const
  archScale {.intdefine.} = 1
    ## Multiplier applied to the number of components and entity shapes, which grows the
    ## work roughly linearly. The action counts are deliberately left out of this: they
    ## grow the archetype count exponentially, so they get dialed on their own.

  archComponents {.intdefine.} = 40 * archScale
    ## Total number of distinct components in play

  archCore {.intdefine.} = 6
    ## Number of "core" components -- the position/sprite/health style components that
    ## show up in nearly every entity and in most query filters

  archSpawns {.intdefine.} = 20 * archScale
    ## Number of distinct spawned entity shapes

  archAttaches {.intdefine.} = 8
    ## Number of attachable actions. This is the primary driver of combinatorial growth:
    ## every extra unfiltered attach roughly doubles the resulting archetype count, so
    ## nudge this one a step at a time

  archDetaches {.intdefine.} = 8
    ## Number of detachable actions

  archAttachDetach {.intdefine.} = 3
    ## Number of combined attach/detach actions

  archAccessories {.intdefine.} = 6
    ## Number of components flagged as accessories

proc comp(id: int): string =
  "c" & $id

proc uniqueId(value: string): uint16 =
  ## Components are named `c<id>`, so the id can be read straight back out. The real
  ## `ComponentDef` stores this in a field, so keep it cheap enough that it doesn't
  ## show up in the profile as work the compiler wouldn't actually be doing
  for i in 1 ..< value.len:
    result = result * 10 + uint16(value[i].ord - '0'.ord)

proc pick(rand: var Rand, count: HSlice[int, int], low, high: int): seq[string] =
  ## Picks somewhere in `count` distinct components from the range `low ..< high`
  for _ in 0 ..< rand.rand(count):
    let chosen = comp(rand.rand(low ..< high))
    if chosen notin result:
      result.add(chosen)

proc buildWorkload(): int =
  var builder = newArchetypeBuilder[string]()

  # Each phase gets its own seed so that changing one knob doesn't shift the random
  # stream used by the others. Dialing up the spawns leaves the actions untouched.
  var rand = initRand(0x2545F4914F6CDD1D)

  # Entity shapes: a couple of core components plus a handful of specific ones
  for _ in 0 ..< archSpawns:
    let comps =
      rand.pick(1 .. 3, 0, archCore) & rand.pick(2 .. 5, archCore, archComponents)
    builder.define(comps)

  # Attachable components, usually gated behind a filter on the core components
  rand = initRand(0x1E3779B97F4A7C15)
  for i in 0 ..< archAttaches:
    let filter =
      if i mod 3 == 0:
        builder.filter([], [])
      else:
        builder.filter(
          rand.pick(1 .. 2, 0, archCore), rand.pick(1 .. 1, 0, archCore)
        )
    builder.attachable(rand.pick(1 .. 2, archCore, archComponents), filter)

  # Detachable components
  rand = initRand(0x3F58476D1CE4E5B9)
  for _ in 0 ..< archDetaches:
    builder.detachable(
      rand.pick(1 .. 2, archCore, archComponents),
      rand.pick(0 .. 1, archCore, archComponents),
    )

  # Components that get swapped in and out at the same time
  rand = initRand(0x14D049BB133111EB)
  for _ in 0 ..< archAttachDetach:
    builder.attachDetach(
      attach = rand.pick(1 .. 2, archCore, archComponents),
      detach = rand.pick(1 .. 1, archCore, archComponents),
      optDetach = rand.pick(0 .. 1, archCore, archComponents),
      filter = builder.filter(rand.pick(1 .. 1, 0, archCore), []),
    )

  for i in 0 ..< archAccessories:
    builder.accessory(comp(archCore + i))

  return builder.build().toSeq.len

const archetypeCount = buildWorkload()

static:
  echo "Archetypes: ", archetypeCount

when isMainModule:
  echo "Archetypes: ", archetypeCount
