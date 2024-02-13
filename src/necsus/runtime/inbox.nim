type
    MailboxPtr[T] = ptr seq[T]

    Inbox*[T] = distinct MailboxPtr[T]
        ## Receives events

iterator items*[T](inbox: Inbox[T]): lent T {.inline.} =
    ## Iterate over inbox items
    for message in items(MailboxPtr[T](inbox)[]):
        yield message

proc len*[T](inbox: Inbox[T]): uint {.inline.} = MailboxPtr[T](inbox)[].len.uint
    ## The number of events in this inbox