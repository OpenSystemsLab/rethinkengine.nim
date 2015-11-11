import macros, typeinfo, typetraits, tables, asyncdispatch, strutils
import ../../rethinkdb.nim/rethinkdb

include private/utils.nim
import times

const
  FIELD_PREFIX = "m"

var
  r: RethinkClient

proc open*(address = "127.0.0.1", port = Port(28015), auth, db = "") =
  r = newRethinkClient(address, port, auth, db)

type
  RethinkDocument* {.inheritable.} = object
    mId: string
    isDirty*: bool

method id*(self: auto): string = self.mId
proc `id=`*(self: var auto, val: string) = self.mId = val

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
    fieldName, fieldType: NimNode
    newFieldName, setter: NimNode
    #fieldType = @["string"]

  var recList = newNimNode(nnkRecList)
  var setterGetterProcs = newStmtList()

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
          fieldName = n[0]
          fieldType = n[1]

          fieldList.add($fieldName)

          setter = newNimNode(nnkAccQuoted)
          setter.add(fieldName)
          setter.add(ident("="))

          newFieldName = ident(FIELD_PREFIX & capitalize($fieldName))
          n[0] = newFieldName
          recList.add(n)
          setterGetterProcs.add quote do:
            method `fieldName`*(self: `docName`): `fieldType` = self.`newFieldName`
            proc `setter`*(self: var `docName`, val: `fieldType`) =
              if not self.isDirty and self.`newFieldName` != val:
                self.isDirty = true
              self.`newFieldName` = val

      else:
        result.add(node)

  result.insert(0,
    if baseName == nil:
      quote do:
        type `docName` = ref object of RethinkDocument
    else:
      quote do:
        type `docName` = ref object of `baseName`
  )
  result[0][0][0][2][0][2] = recList

  var getDataProc =  quote do:
    proc getData*(self: `docName`): MutableDatum =
      &*{"id": self.mId}

  # small hack: I dont know how to create a nnkSym node
  var sym =  getDataProc[0][6][0][1][0][1][0]

  for f in fieldList:
    #var e = newColonExpr(newStrLitNode(f), newDotExpr(sym, ident(FIELD_PREFIX & capitalize(f))))
    var e = newColonExpr(newStrLitNode(f), newDotExpr(sym, ident(f)))
    getDataProc[0][6][0][1].add(e)

  var newproc = ident("new" & capitalize($docName))
  var saveProc = quote do:
    proc `newproc`*(): `docName` =
      var doc: `docName`
      new(doc)
      doc.isDirty = false

      doc

    proc save*(doc: `docName`) =
      if not doc.isDirty:
        return

      waitFor r.connect()
      echo(%doc.getData())
      #discard waitFor r.table(name(`docName`)).insert([doc.getData()]).run(r)
  echo getDataProc.treeRepr
  result.add(setterGetterProcs)
  result.add(getDataProc)
  result.add(saveProc)
  #echo result.treeRepr
