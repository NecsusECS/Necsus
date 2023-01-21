import macros

## The variable used to reference the initial size of any structs
let confIdent* {.compileTime.} = ident("config")

## The variable for identifying the local world
let worldIdent* {.compileTime.} = ident("world")

## A variable that represents the time that the current tick started
let thisTime* {.compileTime.} = ident("thisTime")

## A variable that represents the time that execution started
let startTime* {.compileTime.} = ident("startTime")
