import macros, typeinfo, typetraits, tables, asyncdispatch, ../../rethinkdb.nim/rethinkdb

type
  RethinkDocument* {.inheritable.} = object
    id*: string

proc `&`*(a: Any): MutableDatum =
  case a.kind
  of akBool:
    &getBool(a)
  of akChar:
    &($getChar(a))
  of akEnum:
    &(getEnumOrdinal(a, getEnumField(a)))
  of akArray, akSequence:
    if a.kind == akSequence and isNil(a):
      nil
    else:
      var tmp: seq[MutableDatum] = @[]
      for i in 0 .. a.len-1:
        tmp.add(&a[i])
      &tmp
  of akObject, akTuple:
    var tmp = newTable[string, MutableDatum]()
    for key, val in fields(a):
      tmp[key] = &val
    &tmp
  of akSet:
    var tmp: seq[MutableDatum] = @[]
    for e in elements(a):
      tmp.add(&e)
    &tmp
  of akRange:
    &skipRange(a)
  of akCString:
    &($getCString(a))
  of akString:
    &getString(a)
  of akInt..akInt64, akUInt..akUInt64:
    &getBiggestInt(a)
  of akFloat..akFloat128:
    &getBiggestFloat(a)
  else:
    nil

macro document*(head: expr, body: stmt): stmt {.immediate.} =
  ## A new Rethink Engine document defination.
  ## Copied from https://nim-by-example.github.io/oop_macro

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
        type `docName` = object of RethinkDocument
    else:
      quote do:
        type `docName` = object of `baseName`
  )
  result[0][0][0][2][2] = recList

  #echo result.treeRepr


proc save*[T](r: RethinkClient, doc: T) =
  var d: T
  var data = newTable[string, MutableDatum]()

  shallowCopy(d, doc)

  for name, value in toAny(d).fields():
    data[name] = &value

    echo name, ", ", value.kind, ", ", value.rawType

  discard waitFor r.table("Software").insert([&data]).run(r)



when isMainModule:
  document Cat:
    var name: string
    method vocalize: string =
      echo this.name
      "meow"
  var c: Cat
  c.name = "Lisa"

  echo c.vocalize()
