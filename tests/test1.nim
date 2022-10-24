import unittest

import
  std / [os, osproc]

setCurrentDir("demo")
include "src/csv2dbsrc.nim"

test "created dbtables nim file":
  echo execProcess("nimble test")
