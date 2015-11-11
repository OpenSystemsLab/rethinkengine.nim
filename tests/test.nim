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
  Tags {.borrow: `.`.} = seq[string]

document Version:
  var version: string
  var updatedAt: TimeInfo

document Software:
  var name: string
  var description: string
  var homepage: string
  var tags: Tags
  var version: string
  var lastCheckedAt: TimeInfo


open()

var
  soft: Software
  v: Version

new(soft)
new(v)

v.version = "0.0.1"

soft.id = "nginx"
soft.name = "nginx"
#soft.tags.add("linux")
soft.save()

#r.close()
