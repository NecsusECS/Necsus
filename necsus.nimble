# Package

version = "0.13.0"
author = "Nycto"
description = "Entity Component System"
license = "MIT"
srcDir = "src"

# Dependencies

requires "nim >= 1.6.0"

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
                exec("nim c -r -p:" & getCurrentDir() & "/src --experimental:callOperator --threads:on " & tmpPath)
                accum = ""
                count += 1

            inCode = not inCode
        elif inCode:
            accum &= line & "\n"

task documentation, "Generates API documentation":
    exec("nimble -y doc --index:on --out:docs --project src/necsus.nim")

    let (body, code) = gorgeEx("~/.nimble/bin/markdown < README.md")
    assert(code == 0, body)
    writeFile("docs/index.html", readFile("docs/index.tpl.html").replace("{body}", body))
