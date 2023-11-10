import threads, sharedVector

##
## A simple mailbox of messages. This is not currently thread safe
##

type
    Mailbox*[T] = object
        ## A mailbox of messages
        next: Atomic[uint]
        messages: SharedVector[T]

proc newMailbox*[T](initialSize: SomeInteger): Mailbox[T] =
    ## Creates a new mailbox
    result.messages = newSharedVector[T](initialSize.uint)

proc send*[T](mailbox: var Mailbox[T], message: sink T) =
    ## Add a message to this mailbox
    let index = mailbox.next.fetchAdd(1)
    mailbox.messages[index] = message

iterator items*[T](mailbox: var Mailbox[T]): lent T =
    ## Iterate through each item in this mailbox
    let max = mailbox.next.load
    var accum = 0'u
    for message in mailbox.messages.items:
        accum += 1
        if accum > max:
            break
        yield message

proc clear*[T](mailbox: var Mailbox[T]) =
    ## Remove all messages from this mailbox
    mailbox.next.store(0)

proc len*[T](mailbox: var Mailbox[T]): uint {.inline.} = mailbox.next.load
    ## Returns the number of messages in this mailbox