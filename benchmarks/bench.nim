import times, os, strutils

template benchmark*(benchmarkName: string, totalOps: int, code: untyped) =
    block:
        let t0 = epochTime()
        code
        let elapsed = epochTime() - t0
        echo benchmarkName
        echo "  CPU Time: ", formatFloat(elapsed * 1_000, ffDecimal, precision = 4), " ms"
        echo "  Ops per second: ", formatFloat(float(totalOps) / elapsed, ffDecimal, precision = 2), " op/s"
        echo "  Op speed: ", formatFloat(elapsed / float(totalOps) * 1_000_000_000, ffDecimal, precision = 2), " ns/op"

template benchmarkLoop*(benchmarkName: string, totalOps: int, iters: int, code: untyped) =
    ## Runs `code` `iters` times and reports per-op time. Use for operations that are too fast to
    ## measure reliably in a single run.
    block:
        let t0 = epochTime()
        for benchmarkLoopI in 0 ..< iters:
            code
        let elapsed = epochTime() - t0
        echo benchmarkName
        echo "  CPU Time: ", formatFloat(elapsed / float(iters) * 1_000, ffDecimal, precision = 4), " ms"
        echo "  Ops per second: ", formatFloat(float(totalOps) / (elapsed / float(iters)), ffDecimal, precision = 2), " op/s"
        echo "  Op speed: ", formatFloat((elapsed / float(iters)) / float(totalOps) * 1_000_000_000, ffDecimal, precision = 2), " ns/op"
