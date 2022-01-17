import tables, atomics, math, sequtils, strutils

type
    Entry*[T] = tuple[key: int, value: T]

    IntTable*[T] {.byref.} = object
        ## A packed tabled where the key is always an int
        keyMap: Table[int, int]
        entries: seq[Entry[T]]
        maxIndex: int

proc newIntTable*[T](initialSize: int): IntTable[T] =
    ## Create a new IntTable
    result = IntTable[T](
        keyMap: initTable[int, int](initialSize),
        entries: newSeq[Entry[T]](initialSize)
    )

proc `[]`*[T](table: IntTable[T], key: int): lent T =
    ## Fetch a value
    table.entries[table.keyMap[key]].value

proc `[]=`*[T](table: var IntTable[T], key: int, value: sink T) =
    ## Add a value
    let nextIndex = table.maxIndex
    table.maxIndex += 1
    if nextIndex >= table.entries.len:
        table.entries.setLen(ceilDiv(nextIndex * 3, 2))
    table.entries[nextIndex] = (key, value)
    table.keyMap[key] = nextIndex

proc contains*[T](table: IntTable[T], key: int): bool =
    ## Determine whether a key exists in this table
    key in table.keyMap

iterator items*[T](table: IntTable[T]): lent T =
    ## Iterate through all values
    for i in 0..<table.maxIndex:
        yield table.entries[i].value

iterator pairs*[T](table: IntTable[T]): lent Entry[T] =
    ## Iterate through all values
    for i in 0..<table.maxIndex:
        yield table.entries[i]

proc `$`*[T](table: IntTable[T]): string =
    ## Debug string generation
    result = "{"
    var first = true
    for (key, value) in table.pairs:
        if first: first = false else: result.add ", "
        result.add $key
        result.add ": "
        result.add $value
    result.add "}"

proc del*[T](table: var IntTable[T], key: int) =
    ## Removes a key from this table
    let idx = table.keyMap[key]
    table.keyMap.del(key)
    table.maxIndex -= 1
    if table.maxIndex > 0:
        let toCopy = table.entries[table.maxIndex]
        table.entries[idx] = toCopy
        table.keyMap[toCopy.key] = idx

