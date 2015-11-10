import macros, typeinfo, typetraits, tables, asyncdispatch
import ../../rethinkdb.nim/rethinkdb

include private/utils.nim
import times


type
  RethinkDocument* {.inheritable.} = object
    id: string
    isDirty*: bool

macro document*(head: expr, body: stmt): stmt {.immediate.} =
  ## A new Rethink Engine document defination.
  ##
  ## document Model:
  ##   var name: string
  ##   var age: int
  ##   method preSave = echo self.name
  ##
  ## will becomes:
  ## ============
  ##
  ## type
  ##   Model* = RethinkDocument
  ##     data = tuple(name: string, age: int)
  ##  method name(): string = name
  ##  method name(name: string) = self.name = name
  ##  method age(): string = age
  ##  method age(age: string) = self.age = age
  ##
  ##  method preSave(self: Model) =
  ##   echo self.name


  var docName, baseName: NimNode

  if head.kind == nnkIdent:
    docName = head

  elif head.kind == nnkInfix and $head[0] == "of":
    docName = head[1]
    baseName = head[2]
  else:
    quit "Invalid node: " & head.lispRepr

  result = newStmtList()

  var
    fieldList: seq[string] = @[]
    #fieldType = @["string"]

  var recList = newNimNode(nnkRecList)

  for node in body.children:
    case node.kind:
      of nnkMethodDef, nnkProcDef:
        # inject `this: T` into the arguments
        let p = copyNimTree(node.params)
        p.insert(1, newIdentDefs(ident"this", docName))
        node.params = p
        result.add(node)

      of nnkVarSection:
        # variables get turned into fields of the type.
        for n in node.children:

          fieldList.add($n[0])
          #fieldType.add($n[1])

          recList.add(n)
      else:
        result.add(node)

  result.insert(0,
    if baseName == nil:
      quote do:
        type `docName` = object of RethinkDocument
    else:
      quote do:
        type `docName` = object of `baseName`
  )
  result[0][0][0][2][2] = recList

  var setterGetter = quote do:
    method id*(self: `docName`): string = self.id
    #proc `@id=`*(self: `docName`, id: string) = self.id = id

  var getDataProc =  quote do:
    method getData*(self: `docName`): MutableDatum =
      &*{"id": self.id}

  # small hack: I dont know how to create a nnkSym node
  var sym =  getDataProc[0][6][0][1][0][1][0]
  for f in fieldList:
    var e = newColonExpr(newStrLitNode(f), newDotExpr(sym, ident(f)))
    getDataProc[0][6][0][1].add(e)

  var saveProc = quote do:
    proc save*(r: RethinkClient, doc: `docName`) =
      if not doc.isDirty:
        return
      discard waitFor r.table(name(`docName`)).insert([doc.getData]).run(r)

  result.add(setterGetter)
  result.add(getDataProc)
  result.add(saveProc)
  #echo result.treeRepr
