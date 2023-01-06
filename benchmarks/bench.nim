import times, os, strutils

template benchmark*(benchmarkName: string, totalOps: int, code: untyped) =
    block:
        let t0 = epochTime()
        code
        let elapsed = epochTime() - t0
        echo benchmarkName
        echo "  CPU Time: ", formatFloat(elapsed, ffDecimal, precision = 4), " s"
        echo "  Ops per second: ", formatFloat(float(totalOps) / elapsed, ffDecimal, precision = 2), " op/s"
        echo "  Op speed: ", formatFloat(elapsed / float(totalOps) * 1_000_000_000, ffDecimal, precision = 2), " ns/op"
