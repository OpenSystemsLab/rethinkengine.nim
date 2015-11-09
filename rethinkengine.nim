import typeinfo, typetraits, tables, asyncdispatch, ../../rethinkdb.nim/rethinkdb

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


proc save*[T](r: RethinkClient, doc: T) =
  var d: T
  var data = newTable[string, MutableDatum]()

  shallowCopy(d, doc)

  for name, value in toAny(d).fields():
    data[name] = &value

    echo name, ", ", value.kind, ", ", value.rawType

  discard waitFor r.table("Software").insert([&data]).run(r)
