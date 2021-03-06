import ../util/mailbox

type
    Inbox*[T] {.byref.} = object
        ## Receives events
        mailbox: ptr Mailbox[T]

proc newInbox*[T](mailbox: var Mailbox[T]): Inbox[T] =
    result.mailbox = addr mailbox

iterator items*[T](inbox: Inbox[T]): lent T =
    ## Iterate over inbox items
    for message in inbox.mailbox[].items:
        yield message
