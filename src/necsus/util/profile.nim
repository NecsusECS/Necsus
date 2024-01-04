import algorithm, sequtils, strformat, strutils, ../runtime/necsusConf

const READINGS = 600'u

type
    Profiler* = object
        name*: string
        next: uint
        readings: array[READINGS, float]

proc record*(profiler: var Profiler, time: float) =
    ## Records a reading
    profiler.readings[profiler.next mod READINGS] = time
    profiler.next += 1

proc format(seconds: float): string =
    formatBiggestFloat(seconds * 1_000_000, ffDecimal, 3) & " μs"

proc summarize*(profilers: var openarray[Profiler], conf: NecsusConf) =
    var slowest: seq[(float, float, string)]
    for profiler in profilers.mitems:
        if profiler.next mod READINGS == 0 and profiler.next > 0:
            profiler.readings.sort()
            if profiler.readings[READINGS div 2] > 0:
                let median = profiler.readings[READINGS div 2]
                let average = foldl(profiler.readings, a + b) / READINGS.float
                slowest.add((median, average, profiler.name))

    if slowest.len > 0:
        for (median, average, name) in slowest.sortedByIt(it[0]).reversed():
            conf.log(fmt("Profile -- med: {format(median):>10}, avg: {format(average):>10} -- {name}"))