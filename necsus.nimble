# Package

version = "0.1.0"
author = "Nycto"
description = "Entity Component System"
license = "MIT"
srcDir = "src"

# Dependencies

requires "nim >= 1.6.0"
requires "threading >= 0.1.0"

task benchmark, "Executes a suite of benchmarks":
    for script in ["packed1", "packed5", "updates"]:
        exec("nim r -d:release --verbosity:0 --hints:off ./benchmarks/" & script & ".nim")
