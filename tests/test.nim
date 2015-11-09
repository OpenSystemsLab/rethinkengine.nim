import ../rethinkengine
import marshal
import ../../rethinkdb.nim/rethinkdb
import tables
import json
import asyncdispatch
import times
import typeinfo
import typetraits
type
  Version* = object of RethinkDocument
    version*: string
    updatedAt: TimeInfo
  Software* = object of RethinkDocument
    name*: string
    description*: string
    homepage*: string
    tags*: seq[string]
    version*: string
    lastCheckedAt*: TimeInfo
    versions: seq[Version]


#var r = newRethinkClient()
#waitFor r.connect()

var soft: Software
var v: Version
v.version = "0.0.1"

soft.id = "nginx"
soft.name = "nginx"
soft.versions = @[]
soft.versions.add(v)


var t: TimeInfo

echo name(type(t))

echo (%(&(toAny(soft))))

for name, value in toAny(soft).fields():
  echo name, ", ", value.kind
  if not value.isNil:
    echo value.repr


#r.save(soft)

#r.close()
