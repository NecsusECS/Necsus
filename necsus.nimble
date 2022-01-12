# Package

version = "0.1.0"
author = "Nycto"
description = "Entity Component System"
license = "MIT"
srcDir = "src"

# Dependencies

requires "nim >= 1.6.0"

task benchmark, "Executes a suite of benchmarks":
    exec("nim r -d:release --verbosity:0 --hints:off ./benchmarks/packed1.nim")
    exec("nim r -d:release --verbosity:0 --hints:off ./benchmarks/packed5.nim")
