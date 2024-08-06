
proc isAboveNimVersion*(major, minor, patch: int): bool =
    ## Returns whether the current nim compiler is above a given version
    if NimMajor > major: return true
    if NimMajor < major: return false
    if NimMinor > minor: return true
    if NimMinor < minor: return false
    return NimPatch > patch