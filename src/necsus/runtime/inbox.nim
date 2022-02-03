import packedList

type
    Inbox*[T] {.byref.} = object
        ## Receives events
        backingList: ptr PackedList[T]

proc newInbox*[T](backingList: var PackedList[T]): Inbox[T] =
    result.backingList = addr backingList

iterator items*[T](inbox: Inbox[T]): lent T =
    ## Iterate over inbox items
    for message in inbox.backingList[].items:
        yield message
