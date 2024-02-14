import ../util/[sharedVector, threads]

##
## A simple mailbox of messages. This is not currently thread safe
##

type
    Mailbox*[T] = object
        ## A mailbox of messages
        next: Atomic[uint]
        messages: SharedVector[T]

    MailboxPtr[T] = ptr Mailbox[T]

    Inbox*[T] = distinct MailboxPtr[T]
        ## Receives events

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

iterator items*[T](inbox: Inbox[T]): lent T {.inline.} =
    ## Iterate over inbox items
    for message in items(MailboxPtr[T](inbox)[]):
        yield message

proc len*[T](inbox: Inbox[T]): uint {.inline.} = MailboxPtr[T](inbox)[].len.uint
    ## The number of events in this inbox