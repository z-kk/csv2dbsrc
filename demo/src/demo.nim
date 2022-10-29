import
  std / os

proc createConfDir() =
  let dir = getConfigDir() / getAppFilename().extractFilename
  dir.createDir

when isMainModule:
  createConfDir()
  echo "run nimble test"
