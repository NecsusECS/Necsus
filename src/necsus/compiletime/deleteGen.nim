import tables, macros
import archetype, tools, systemGen, archetypeBuilder, worldEnum, commonVars
import ../runtime/[archetypeStore, world, directives]

proc worldFields(name: string): seq[WorldField] = @[ (name, bindSym("Delete")) ]

proc generate(details: GenerateContext): NimNode =
    ## Generates the code for instantiating queries
    case details.hook
    of GenerateHook.Standard:
        let deleteProc = details.name.ident
        let archetypeEnum = details.archetypeEnum.ident
        let entity = ident("entity")
        let entityIndex = ident("entityIndex")

        let cases = details.createArchetypeCase(newDotExpr(entityIndex, ident("archetype"))) do (fromArch: auto) -> auto:
            let archIdent = fromArch.ident
            quote:
                del(`appStateIdent`.`archIdent`, `entityIndex`.archetypeIndex)

        return quote do:
            `appStateIdent`.`deleteProc` = proc(`entity`: EntityId) =
                let `entityIndex` = del[`archetypeEnum`](`appStateIdent`.`worldIdent`, `entity`)
                `cases`
    else:
        return newEmptyNode()

let deleteGenerator* {.compileTime.} = newGenerator("Delete", generate, worldFields)