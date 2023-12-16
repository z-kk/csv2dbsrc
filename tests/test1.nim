import unittest

import
  std / [os, strutils, sequtils, osproc, terminal]

setCurrentDir("demo")
include "src/csv2dbsrc.nim"

test "created dbtables nim file":
  var flg: seq[string]
  flg.add $conf.dbType
  if conf.dbType == mysql and conf.dbPass == "":
    flg.add "usePass"
    flg.add "Passwd=" & readPasswordFromStdin("DB password: ")
  echo execProcess("nimble test " & flg.mapIt("-d:" & it).join(" "))
