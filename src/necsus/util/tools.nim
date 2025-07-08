import std/options

proc isSinkMemoryCorruptionFixed*(): bool =
  ## Returns whether the current version of Nim has a fixed implementation of
  ## the 'sink' parameter that doesn't cause memory corruption.
  ## See https://github.com/nim-lang/Nim/issues/23907
  return (NimMajor, NimMinor) >= (2, 2)

proc isSpawnSinkEnabled*(): bool =
  ## Enables sink parameters for Spawn directives. This is disabled while
  ## debugging memory corruption.
  ## See https://github.com/nim-lang/Nim/issues/23907
  return (NimMajor, NimMinor) >= (2, 3)

proc stringify*[T](value: T): string {.raises: [], gcsafe.} =
  ## Converts a value to a string as best as it can
  try:
    when compiles($value):
      return $value
    elif compiles(value.repr):
      return value.repr
    else:
      return $T
  except:
    return $T & "(Failed to generate string)"

template optionPtr*[T](opt: Option[T]): Option[ptr T] =
  ## Returns a pointer to a value in an option
  if opt.isSome:
    some(unsafeAddr opt.unsafeGet)
  else:
    none(ptr T)
