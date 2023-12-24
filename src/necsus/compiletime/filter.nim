import archetype, tupleDirective, componentDef

proc test*(filter: openarray[DirectiveArg], archetype: Archetype[ComponentDef]): bool =
    ## Checks whether an archetype matches a filter
    for arg in filter:
        case arg.kind
        of DirectiveArgKind.Include:
            if arg.component notin archetype:
                return false
        of DirectiveArgKind.Exclude:
            if arg.component in archetype:
                return false
        of DirectiveArgKind.Optional:
            discard
    return true