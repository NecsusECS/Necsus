type
  SeqPtr[T] = ptr seq[T]

  Inbox*[T] = distinct SeqPtr[T] ## Receives events

iterator items*[T](inbox: Inbox[T]): lent T {.inline.} =
  ## Iterate over inbox items
  for message in items(SeqPtr[T](inbox)[]):
    yield message

proc len*[T](inbox: Inbox[T]): uint {.inline.} = ## The number of events in this inbox
  SeqPtr[T](inbox)[].len.uint
