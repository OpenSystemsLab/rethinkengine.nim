import typeinfo, tables, rethinkdb

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
