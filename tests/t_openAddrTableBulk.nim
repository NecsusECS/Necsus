import unittest, intsets, random, sequtils, algorithm, necsus/util/openAddrTable

suite "OpenAddrTable bulk actions":

    type
        ActionKind = enum SetKey, ChangeKey, DeleteKey

        Action = object
            key: int16
            case kind: ActionKind
            of SetKey, ChangeKey:
                value: int16
            of DeleteKey:
                discard

    proc `$`(action: Action): string =
        case action.kind
        of SetKey: "SET " & $action.key & " = " & $action.value
        of ChangeKey: "UPD " & $action.key & " = " & $action.value
        of DeleteKey: "DEL " & $action.key

    proc randInt16(random: var Rand): int16 =
        (random.next() mod int16.high.uint64).int16

    proc randomAction(random: var Rand, existingKeys: IntSet): Action =
        if existingKeys.len == 0:
            return Action(kind: SetKey, key: random.randInt16(), value: random.randInt16())

        case (random.next() mod 4).int32:
        of 0: return Action(kind: DeleteKey, key: random.sample(existingKeys.toSeq()).int16)
        of 1: return Action(kind: ChangeKey, key: random.sample(existingKeys.toSeq()).int16, value: random.randInt16())
        else: return Action(kind: SetKey, key: random.randInt16(), value: random.randInt16())

    for i in 0..50:
        test "Bulk action tests #" & $i:
            var table = newOpenAddrTable[int16, int16](10)
            var setKeys = initIntSet()
            var actions = newSeq[Action]()
            var random = initRand(i)

            for i in 0..100:
                let action = random.randomAction(setKeys)
                actions.add(action)
                checkpoint $action
                case action.kind
                of SetKey, ChangeKey:
                    table[action.key] = action.value
                    check(table[action.key] == action.value)
                    setKeys.incl action.key
                of DeleteKey:
                    table.del(action.key)
                    expect KeyError: discard table[action.key]
                    setKeys.excl action.key
                checkpoint table.dump()

            var checkedKeys = initIntSet()
            for action in actions.reversed():
                if action.key notin checkedKeys:
                    checkpoint "Checking " & $action
                    checkedKeys.incl action.key
                    case action.kind
                    of SetKey, ChangeKey: check(table[action.key] == action.value)
                    of DeleteKey: expect KeyError: discard table[action.key]
