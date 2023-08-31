# Package

version       = "0.4.3"
author        = "z-kk"
description   = "create db util sources from csv"
license       = "MIT"
srcDir        = "src"
bin           = @["csv2dbsrc"]
binDir        = "bin"


# Dependencies

requires "nim >= 2.0.0"


# Tasks

import os
task r, "run in binDir":
  exec "nimble build"
  exec "nimble ex"

task ex, "run without build":
  withDir binDir:
    for b in bin:
      exec "." / b
