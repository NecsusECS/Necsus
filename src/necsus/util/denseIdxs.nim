import threading/atomics

type
    DenseIdxInt = uint

    DenseIdx* = distinct DenseIdxInt
        ## An index into the dense value table

    AtomicDenseIdx* = object
        ## An atomic reference to a DenseIdx
        value: Atomic[DenseIdxInt]

proc compareExchange*(
    atom: var AtomicDenseIdx;
    expected: var DenseIdx;
    desired: DenseIdx;
    order: Ordering = SeqCst
): bool {.inline.} =
    ## Swaps values in an atomic DenseIdx
    compareExchange(atom.value, DenseIdxInt(expected), DenseIdxInt(desired), order)

proc store*(atom: var AtomicDenseIdx; desired: DenseIdx; order: Ordering = SeqCst) {.inline.} =
    ## Stores a value in an atomic DenseIdx
    store(atom.value, DenseIdxInt(desired), order)

## The "special" value representing an unused key
const Unused* = DenseIdx(0)

## The "special" value representing a tombstoned key
const Tombstoned* = DenseIdx(1)

proc load*(atom: var AtomicDenseIdx; order: Ordering = SeqCst): DenseIdx {.inline.} =
    ## Read a value
    return DenseIdx(load(atom.value, order))

proc isUsed*(idx: DenseIdx): bool {.inline.} =
    ## Whether an index is in use
    DenseIdxInt(idx) > 1

proc isUnused*(idx: DenseIdx): bool {.inline.} =
    ## If an index is unused
    DenseIdxInt(idx) == 0

proc isTombstoned*(idx: DenseIdx): bool {.inline.} =
    ## If an index is tombstoned
    DenseIdxInt(idx) == DenseIdxInt(Tombstoned)

proc idx*(index: DenseIdx): DenseIdxInt {.inline.} =
    ## Converts a dense index to a array index
    DenseIdxInt(index) - 2

proc asDenseIdx*(idx: DenseIdxInt): DenseIdx {.inline.} =
    ## Converts an integer to a dense index
    DenseIdx(idx + 2)

proc `$`*(index: DenseIdx): string =
    ## Stringify a dense index
    if isUnused(index):
        "unused"
    elif isTombstoned(index):
        "tombstoned"
    else:
        `$`(idx(index))
