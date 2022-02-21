

##
## Entry encoding
##

type
    SmallValue* = int8 | int16 | int32 | bool | enum | uint8 | uint16 | uint32
        ## The keys must keep values under 32b so we can squeeze them into an Atomic value

    EntryState* = enum UsedKey, UnusedKey, TombstonedKey
        ## The various states a saved entry can be in

    Entry*[K, V] = distinct int64
        ## An entry in the table

## The bit to mark in a key when it is used
const usedBit*: int64 = 1 shl 63

## The bit to mark in a key when it is tombstoned
const tombstoneBit*: int64 = 1 shl 62

## The maximum value that can be stored in a key
const maxValue*: uint32 = not (1.uint32 shl 31)

## All possible metadata bits are set
const allBits*: int64 = (usedBit or tombstoneBit)

## A mask that can be used to clear all metadata bits
const clearFlagsMask*: int64 = not allBits

proc encode*[K: SmallValue, V: SmallValue](key: K, value: V, state: static EntryState): Entry[K, V] {.inline.} =
    ## Encodes a key and value into an entry
    assert(key.uint32 <= maxValue, "Key is too big to fit in this table: " & $key)
    assert(value.uint32 <= maxValue, "Value is too big to fit in this table: " & $value)

    let metadata: int64 =
        when state == UnusedKey: 0
        elif state == UsedKey: usedBit
        elif state == TombstonedKey: tombstoneBit

    return Entry[K, V](metadata or (value.int64 shl 31) or key.int64)

proc value*[K, V](entry: Entry[K, V]): V {.inline.} =
    ## Pulls the value out of an entry
    V((entry.int64 and clearFlagsMask) shr 31)

proc key*[K, V](entry: Entry[K, V]): K =
    ## Pulls the value out of an entry
    K(entry.int64 and maxValue.int64)

proc isState*[K, V](entry: Entry[K, V], state: static[EntryState]): bool {.inline.} =
    ## Returns whether a key is currently considered "in use"
    when state == UsedKey: (entry.int64 and usedBit) != 0
    elif state == TombstonedKey: (entry.int64 and tombstoneBit) != 0
    elif state == UnusedKey: (entry.int64 and allBits) == 0

proc isWritable*[K, V](entry: Entry[K, V]): bool {.inline.} =
    ## Returns whether a key is available to be written to
    (entry.int64 and allBits) != usedBit

proc `$`*[K, V](entry: Entry[K, V]): string =
    ## Stringify an entry
    $entry.key & ": " & $entry.value

proc dump*[K, V](entry: Entry[K, V]): string =
    ## Stringify an entry
    if entry.isState(UsedKey): return $entry
    elif entry.isState(TombstonedKey): return "T"
    elif entry.isState(UnusedKey): return "X"
