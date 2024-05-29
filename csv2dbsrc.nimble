# Package

version       = "0.5.1"
author        = "z-kk"
description   = "create db util sources from csv"
license       = "MIT"
srcDir        = "src"
bin           = @["csv2dbsrc"]
binDir        = "bin"


# Dependencies

requires "nim >= 2.0.0"
requires "docopt >= 0.7.1"


# Tasks

import os
task r, "run in binDir":
  exec "nimble build"
  exec "nimble ex"

task ex, "run without build":
  withDir binDir:
    for b in bin:
      exec "." / b


# Before / After

before build:
  let infoFile = srcDir / bin[0] & "pkg" / "nimbleInfo.nim"
  infoFile.parentDir.mkDir
  infoFile.writeFile("""
    const
      AppName* = "$#"
      Version* = "$#"
  """.dedent % [bin[0], version])

after build:
  let infoFile = srcDir / bin[0] & "pkg" / "nimbleInfo.nim"
  infoFile.writeFile("""
    const
      AppName* = "app"
      Version* = "0"
  """.dedent)
