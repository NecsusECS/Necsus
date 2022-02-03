# Package

version = "0.1.0"
author = "Nycto"
description = "Entity Component System"
license = "MIT"
srcDir = "src"

# Dependencies

requires "nim >= 1.6.0"
requires "threading >= 0.1.0"

import os

task benchmark, "Executes a suite of benchmarks":
    for script in ["packed1", "packed5", "updates"]:
        exec("nim r -d:release --verbosity:0 --hints:off ./benchmarks/" & script & ".nim")

task readme, "Compiles code in the readme":
    let readme = readFile("README.md")
    var inCode = false
    var accum = ""
    var count = 0
    for line in readme.split("\n"):
        if line.startsWith "```":

            if inCode:
                let tmpPath = getTempDir() & "necsus_readme_" & $count & ".nim"
                writeFile(tmpPath, accum)
                exec("nim c -r --threads:on " & tmpPath)
                accum = ""
                count += 1

            inCode = not inCode
        elif inCode:
            accum &= line & "\n"
