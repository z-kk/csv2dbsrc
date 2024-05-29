import
  std / [os, strutils, json, rdstdin, terminal],
  docopt,
  csv2dbsrcpkg / [variables, makeNimFile, nimbleInfo]

var
  isExist: bool
  pkgDir: string

proc readCmdOpt() =
  ## コマンドラインオプションを確認
  let doc = """
    $1

    Usage:
      $1

    Options:
      -h --help   Show this screen.
      --version   Show version.
  """ % [AppName]
  let args = doc.dedent.docopt(version = Version)
  discard args

proc readNimble() =
  ## nimble の情報を読み込む
  var srcDir: string
  for f in walkFiles("*.nimble"):
    for line in f.lines:
      if line.find("srcDir") == 0:
        srcDir = line[line.find("=") + 1 .. ^1].strip[1..^2]

  if srcDir == "":
    srcDir = "."
    pkgDir = "."
  else:
    for f in walkFiles(srcDir / "*.nim"):
      if dirExists(f[0..^5] & "pkg"):
        pkgDir = f[0..^5] & "pkg"
        break
      elif dirExists(f[0..^5]):
        pkgDir = f[0..^5]
        break
    if pkgDir == "":
      for d in walkDirs(srcDir / "*"):
        if d == srcDir / CsvDir:
          continue
        pkgDir = d
    if pkgDir == "":
      pkgDir = srcDir

proc readConf(): DbConf =
  ## 設定ファイルを読み込む
  let confFile = pkgDir / CsvDir / DbConfFile
  var conf = %*{}
  if confFile.fileExists:
    isExist = true
    conf = confFile.parseFile

  if $dbType notin conf:
    echo "select database type"
    for dt in DbType:
      echo $dt.ord, ": ", dt
    while true:
      let res = readLineFromStdin(">> ")
      try:
        conf[$dbType] = %int(DbType(res.parseInt))
        break
      except:
        echo "invalid value!!"
        continue
  result.dbType = DbType(conf[$dbType].getInt)

  if result.dbType == sqlite:
    if $dbFileName notin conf:
      echo "input database file name"
      let res = readLineFromStdin(">> ")
      conf[$dbFileName] = %res
    if $dbDirName notin conf:
      echo "select database dir"
      for e in DirType.items:
        echo "$1: $2" % [$(e.ord + 1), $e]
      while true:
        try:
          let ipt = readLineFromStdin(">> ")
          let dirType = DirType(ipt.parseInt - 1)
          case dirType
          of dtXdgConfig, dtXdgData:
            conf[$dbDirName] = %dirType
          of dtSameDir:
            conf[$dbDirName] = %"."
          of dtElse:
            conf[$dbDirName] = %readLineFromStdin("dir name: ")
          break
        except:
          discard

    result.dbFileName = conf[$dbFileName].getStr
    result.dbDirName = conf[$dbDirName].getStr

  if result.dbType == mysql:
    if $dbHost notin conf:
      echo "input database host name"
      conf[$dbHost] = %readLineFromStdin(">> ")
    if $dbUser notin conf:
      echo "input database user name"
      conf[$dbUser] = %readLineFromStdin(">> ")
    if $dbPass notin conf:
      let res = readLineFromStdin("save password?[y/N]: ")
      if res.toLowerAscii == "y":
        echo "input database password"
        result.dbPass = readPasswordFromStdin()
        conf[$dbPass] = %result.dbPass
    else:
      result.dbPass = conf[$dbPass].getStr
    if $dbName notin conf:
      echo "input database name"
      conf[$dbName] = %readLineFromStdin(">> ")

    result.dbHost = conf[$dbHost].getStr
    result.dbUser = conf[$dbUser].getStr
    result.dbName = conf[$dbName].getStr

  createDir(pkgDir / CsvDir)
  writeFile(confFile, conf.pretty & "\n")

proc makeSampleCsv(conf: DbConf) =
  ## サンプルcsvを作成する
  var res: seq[seq[string]]
  res.add(@[$name])
  res.add(@["id"])
  res.add(@["user_name"])
  res.add(@["address"])
  res.add(@["tel"])
  res.add(@["group_id"])
  res.add(@["updated_at"])

  res[0].add($comment)
  res[1].add("user id")
  res[2].add("user name")
  res[3].add("")
  res[4].add("")
  res[5].add("user's group id")
  res[6].add("updated date time")

  res[0].add($data_type)
  case conf.dbType
  of sqlite:
    res[1].add("INTEGER")
    res[2].add("TEXT")
    res[3].add("TEXT")
    res[4].add("TEXT")
    res[5].add("INTEGER")
    res[6].add("DATETIME")
  of mysql:
    res[1].add("int")
    res[2].add("varchar")
    res[3].add("varchar")
    res[4].add("varchar")
    res[5].add("int")
    res[6].add("datetime")

    res[0].add($length)
    res[1].add("")
    res[2].add($20)
    res[3].add($100)
    res[4].add($13)
    res[5].add("")
    res[6].add("")

  res[0].add($default_val)
  res[1].add("")
  res[2].add("")
  res[3].add("")
  res[4].add("'000-0000-0000'")
  res[5].add($1)
  res[6].add("'9999-12-31'")

  res[0].add($not_null)
  res[1].add($1)
  res[2].add($1)
  res[3].add("")
  res[4].add("")
  res[5].add($1)
  res[6].add($1)

  res[0].add($is_primary)
  res[1].add($1)
  res[2].add("")
  res[3].add("")
  res[4].add("")
  res[5].add("")
  res[6].add("")

  let f = open(pkgDir / CsvDir / SampleCsv, fmWrite)
  for row in res:
    f.writeLine(row.join(","))

when isMainModule:
  readCmdOpt()
  readNimble()
  let conf = readConf()
  if isExist:
    conf.makeNimFile(pkgDir)
  else:
    conf.makeSampleCsv
    echo "make database table csv referencing ", pkgDir / CsvDir / SampleCsv
