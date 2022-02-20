import tupleDirective, directiveSet, codeGenInfo, macros, sequtils, options, grouper, componentDef
import necsusUtil/packedIntTable

let entityId {.compileTime.} = ident("entityId")

proc localIdent(group: Group[ComponentDef]): NimNode =
    ## Returns an identifier used to store a looked up group storage value
    ident("local_comp_group_" & group.name)

proc createLookupBody(codeGenInfo: CodeGenInfo, lookup: LookupDef): NimNode =
    ## Returns the content of the method when a lookup is possible

    let tupleType = lookup.args.toSeq.asTupleType

    # Generate an or statement for each component group we're looking at
    var allComponentsExist = ident("true")
    for group in codeGenInfo.groups(lookup):
        let compStore = group.componentStoreIdent
        allComponentsExist = quote:
            `allComponentsExist` and contains(`compStore`, int32(`entityId`))

    # Grab references for all storage variables for all the components we care about
    var getGroupInstances = newStmtList()
    for group in codeGenInfo.groups(lookup):
        let compStore = group.componentStoreIdent
        let groupIdent = group.localIdent
        getGroupInstances.add quote do:
            let `groupIdent` = getPointer(`compStore`, int32(`entityId`))

    # Code to instantiate a tuple of components
    var instantiateTuple = nnkTupleConstr.newTree()
    for arg in lookup.args:
        let group = codeGenInfo.compGroups[arg.component]
        let groupIdent = group.localIdent
        let compIndex = group[arg.component]
        if arg.isPointer:
            instantiateTuple.add quote do: addr `groupIdent`[`compIndex`]
        else:
            instantiateTuple.add quote do: `groupIdent`[`compIndex`]

    return quote:
        if `allComponentsExist`:
            `getGroupInstances`
            some[`tupleType`](`instantiateTuple`)
        else:
            return none(`tupleType`)

proc createLookupProc(codeGenInfo: CodeGenInfo, name: string, lookup: LookupDef): NimNode =
    let procName = ident(name)
    let tupleType = lookup.args.toSeq.asTupleType

    # If a component is never spawned or attached, we can never look it up
    let procBody = if lookup.toSeq.allIt(it in codeGenInfo.compGroups):
        createLookupBody(codeGenInfo, lookup)
    else:
        quote: none(`tupleType`)

    return quote:
        proc `procName`(`entityId`: EntityId): Option[`tupleType`] = `procBody`

proc createLookups*(codeGenInfo: CodeGenInfo): NimNode =
    # Creates the methods needed to look up an entity
    result = newStmtList()
    for (name, lookup) in codeGenInfo.lookups:
        result.add(codeGenInfo.createLookupProc(name, lookup))
