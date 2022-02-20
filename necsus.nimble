# Package

version = "0.1.0"
author = "Nycto"
description = "Entity Component System"
license = "MIT"
srcDir = "src"

# Dependencies

requires "nim >= 1.6.0", "threading >= 0.1.0", "https://github.com/NecsusECS/NecsusUtil"

import os

task benchmark, "Executes a suite of benchmarks":
    for file in listFiles("benchmarks"):
        if file.startsWith("benchmarks/b_") and file.endsWith(".nim"):
            echo "Executing: ", file
            exec("nim r " & file)

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
                exec("nimble c -y -r -p:" & getCurrentDir() & "/src --threads:on " & tmpPath)
                accum = ""
                count += 1

            inCode = not inCode
        elif inCode:
            accum &= line & "\n"

task documentation, "Generates API documentation":
    exec("nimble -y doc --index:on --out:docs --project src/necsus.nim")
    exec("cp docs/necsus.html docs/index.html")
