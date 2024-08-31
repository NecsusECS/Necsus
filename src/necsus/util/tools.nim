
proc isAboveNimVersion*(major, minor, patch: int): bool =
    ## Returns whether the current nim compiler is above a given version
    if NimMajor > major: return true
    if NimMajor < major: return false
    if NimMinor > minor: return true
    if NimMinor < minor: return false
    return NimPatch > patch

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