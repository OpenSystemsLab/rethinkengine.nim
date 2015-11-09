import macros, typeinfo, typetraits, tables, asyncdispatch
import ../../rethinkdb.nim/rethinkdb except `[]`

import private/utils.nim

type
  RethinkDocument* {.inheritable.} = object
    data*: TableRef[string, MutableDatum]
    isDirty: bool

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
          recList.add(n)
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
  result[0][0][0][2][2] = recList

  echo result.treeRepr


proc save*[T](r: RethinkClient, doc: T) =
  discard waitFor r.table(doc.tableName).insert([doc.data]).run(r)

type
  Model* = ref object of RethinkDocument

proc newModel*(): Model =
  new(result)
  result.isDirty = false
  result.data = newTable[string, MutableDatum]()


method name(self: Model): string = %%self.data["name"]
proc `name=`(self: Model, name: string) = self.data["name"] = name
method age(self: Model): int = %%self.data["age"]
proc `age=`(self: Model, age: int) = self.data["age"] = age

method preSave(self: Model) =
  echo self.data.name


var m = newModel()
m.id = "123"
m.name = "Lisa"
echo m[]
