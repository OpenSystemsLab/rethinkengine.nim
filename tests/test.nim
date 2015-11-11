import ../rethinkengine
import marshal
import ../../rethinkdb.nim/rethinkdb
import tables
import json
import asyncdispatch
import times
import typeinfo
import typetraits

document Version:
  var version: string
  var updatedAt: TimeInfo

document Software:
  var name: string
  var description: string
  var homepage: string
  var tags: seq[string]
  var version: string
  var lastCheckedAt: TimeInfo


open()

var
  soft: Software
  v: Version


v.version = "0.0.1"

soft.id = "nginx"
soft.name = "nginx"
#soft.tags.add("linux")
#soft.save()

#r.close()
