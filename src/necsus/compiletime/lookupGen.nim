import tupleDirective, directiveSet, codeGenInfo, macros, sequtils, options
import ../runtime/packedIntTable

proc createLookup(codeGenInfo: CodeGenInfo, name: string, lookup: LookupDef): NimNode =
    let entityId = ident("entityId")
    let procName = ident(name)
    let tupleType = lookup.args.toSeq.asTupleType

    # Generate an or statement for each component we're looking at
    var allComponentsExist = ident("true")
    for component in lookup:
        let compStore = component.componentStoreIdent
        allComponentsExist = quote:
            `allComponentsExist` and contains(`compStore`, int32(`entityId`))

    # Code to instantiate a tuple of components
    var instantiateTuple = nnkTupleConstr.newTree()
    for component in lookup:
        let component = component.componentStoreIdent
        instantiateTuple.add quote do: `component`[int32(`entityId`)]

    return quote:
        proc `procName`(`entityId`: EntityId): Option[`tupleType`] =
            if `allComponentsExist`:
                some[`tupleType`](`instantiateTuple`)
            else:
                return none(`tupleType`)

proc createLookups*(codeGenInfo: CodeGenInfo): NimNode =
    # Creates the methods needed to look up an entity
    result = newStmtList()
    for (name, lookup) in codeGenInfo.lookups:
        result.add(codeGenInfo.createLookup(name, lookup))
