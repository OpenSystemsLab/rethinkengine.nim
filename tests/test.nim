import ../rethinkengine
import marshal
import ../../rethinkdb.nim/rethinkdb
import tables
import json
import asyncdispatch
import times
import typeinfo

type
  Software* = object of RethinkDocument
    name*: string
    description*: string
    homepage*: string
    tags*: seq[string]
    version*: string
    lastCheckedAt*: TimeInfo


#var r = newRethinkClient()
#waitFor r.connect()

var soft: Software

soft.id = "nginx"
soft.name = "nginx"

echo (%(&(toAny(soft))))

for name, value in toAny(soft).fields():
  echo name, ", ", value.kind, ", ", value.rawType


#r.save(soft)

#r.close()
