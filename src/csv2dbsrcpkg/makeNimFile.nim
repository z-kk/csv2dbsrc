import
  os, strutils, strformat, parsecsv,
  variables, mystrutils

type
  ColumnInfo = object
    name: string
    comment: string
    dataType: string
    length: int
    defaultVal: string
    notNull: bool
    isPrimary: bool

const
  ParentFile = "dbtables.nim"
  DateFormat = "yyyy-MM-dd"
  DateTimeFormat = "yyyy-MM-dd HH:mm:ss"
  intType = ["integer", "int", "tinyint", "smallint", "mediumint", "bigint"]
  floatType = ["real", "float", "double", "decimal", "numeric"]
  boolType = ["bool", "boolean"]
  dateType = ["date", "datetime"]

proc toValueString(col: ColumnInfo, valName: string): string =
  ## make string to match ColumnInfo
  result = valName & "." & col.name
  case col.dataType.toLowerAscii
  of intType, floatType, boolType:
    result = "{" & result & "}"
  of dateType:
    case col.dataType.toLowerAscii
    of "date":
      result &= &".format(\"{DateFormat}\")"
      result = "date('\" & " & result & " & &\"')"
    of "datetime":
      result &= &".format(\"{DateTimeFormat}\")"
      result = "datetime('\" & " & result & " & &\"')"
  else:
    result = "'{" & result & "}'"

proc readCsv(fileName: string, conf: DbConf) =
  ## read csv file and make nim file
  var cp: CsvParser
  defer: cp.close
  var cols: seq[ColumnInfo]
  cp.open(fileName)
  cp.readHeaderRow
  while cp.readRow:
    var col: ColumnInfo
    col.name = cp.rowEntry($name)
    col.comment = cp.rowEntry($comment)
    col.dataType = cp.rowEntry($data_type)
    if $length in cp.headers:
      col.length = try: cp.rowEntry($length).parseInt except: 0
    col.defaultVal = cp.rowEntry($default_val)
    col.notNull = cp.rowEntry($not_null) notin ["", "0"]
    col.isPrimary = cp.rowEntry($is_primary) notin ["", "0"]
    cols.add(col)

  let
    tableName = fileName.extractFilename.changeFileExt("")
    tableCls = tableName.toCamelCase(true) & "Table"
  var res: string = "import\n"
  res &= "  os, strutils, strformat, parsecsv,\n  "
  for col in cols:
    if col.dataType.toLowerAscii in dateType:
      res &= "times,\n  "
      break
  case conf.dbType
  of sqlite:
    res &= "db_sqlite"
  of mysql:
    res &= "db_mysql"

  res &= "\ntype\n  "
  res &= tableCls[0..^6] & "Col* {.pure.} = enum\n    "
  for col in cols:
    res &= &"{col.name}, "
  res[^2..^1] = "\n  "
  res &= tableCls & "* = object\n"
  res &= "    primKey: int\n"
  for col in cols:
    res &= &"    {col.name}*: "
    case col.dataType.toLowerAscii
    of intType:
      res &= "int"
    of floatType:
      res &= "float"
    of boolType:
      res &= "bool"
    of dateType:
      res &= "DateTime"
    else:
      res &= "string"
    res &= "\n"

  block setData:
    res &= &"proc setData{tableCls}*(data: var {tableCls}, colName, value: string) =\n"
    res &= "  case colName\n"
    for col in cols:
      res &= &"  of \"{col.name}\":\n"
      res &= "    try:\n"
      res &= &"      data.{col.name} = value"
      case col.dataType.toLowerAscii
      of intType:
        res &= ".parseInt"
      of floatType:
        res &= ".parseFloat"
      of boolType:
        res &= ".parseBool"
      of dateType:
        res &= ".parse(\""
        case col.dataType.toLowerAscii
        of "date":
          res &= DateFormat
        of "datetime":
          res &= DateTimeFormat
        res &= "\")"
      res &= "\n"
      res &= "    except: discard\n"

  block createTable:
    res &= &"proc create{tableCls}*(db: DbConn) =\n"
    res &= "  let sql = \"\"\"create table if not exists " & tableName & "(\n"
    for col in cols:
      res &= &"    {col.name} {col.dataType}"
      if col.length > 0:
        res &= &"({col.length})"
      if col.defaultVal != "":
        res &= &" default {col.defaultVal}"
      if col.notNull:
        res &= " not null"
      if col.isPrimary:
        res &= " primary key"
      if conf.dbType == mysql and col.comment != "":
        res &= " comment '" & col.comment.replace("'", "\\'") & "'"
      res &= ",\n"
    res = res[0..^3] & "\n  )\"\"\".sql\n"
    res &= "  db.exec(sql)\n"

  block insertRow:
    let valName = "rowData"
    res &= &"proc insert{tableCls}*(db: DbConn, {valName}: {tableCls}) =\n"
    res &= "  var sql = \"insert into " & tableName & "(\"\n"
    for col in cols:
      if col.isPrimary:
        res &= &"  if {valName}.{col.name} > 0:\n"
        res &= &"    sql &= \"{col.name},\"\n"
        break
    res &= "  sql &= \"\"\""
    for col in cols:
      if col.isPrimary:
        continue
      res &= col.name & ","
    res[^1] = '\n'
    res &= "    ) values (\"\"\"\n"
    for col in cols:
      if col.isPrimary:
        res &= &"  if {valName}.{col.name} > 0:\n"
        res &= &"    sql &= &\"{{{valName}.{col.name}}},\"\n"
        break
    res &= "  sql &= &\""
    for col in cols:
      if col.isPrimary:
        continue
      res &= col.toValueString(valName) & ","
    res[^1] = '"'
    res &= "\n  sql &= \")\"\n"
    res &= "  db.exec(sql.sql)\n"

    res &= &"proc insert{tableCls}*(db: DbConn, {valName}Seq: seq[{tableCls}]) =\n"
    res &= &"  for {valName} in {valName}Seq:\n"
    res &= &"    db.insert{tableCls}({valName})\n"

  block selectTable:
    res &= &"proc select{tableCls}*(db: DbConn, whereStr = \"\", orderStr = \"\"): seq[{tableCls}] =\n"
    res &= &"  var sql = \"select * from {tableName}\"\n"
    res &= "  if whereStr != \"\":\n"
    res &= "    sql &= \" where \" & whereStr\n"
    res &= "  if orderStr != \"\":\n"
    res &= "    sql &= \" order by \" & orderStr\n"
    res &= "  let rows = db.getAllRows(sql.sql)\n"
    res &= "  for row in rows:\n"
    res &= &"    var res: {tableCls}\n"
    for col in cols:
      if col.isPrimary:
        res &= &"    res.primKey = row[{tableCls[0..^6]}Col.{col.name}.ord].parseInt\n"
      res &= &"    res.setData{tableCls}(\"{col.name}\", row[{tableCls[0..^6]}Col.{col.name}.ord])\n"
    res &= "    result.add(res)\n"

  block updateTable:
    let valName = "rowData"
    res &= &"proc update{tableCls}*(db: DbConn, {valName}: {tableCls}) =\n"
    res &= &"  if {valName}.primKey < 1: return\n"
    res &= &"  var sql = \"update {tableName} set \"\n"
    res &= "  sql &= &\""
    for col in cols:
      if col.isPrimary:
        continue
      res &= &"{col.name} = " & col.toValueString(valName) & ","
    res[^1] = '"'
    for col in cols:
      if col.isPrimary:
        res &= &"\n  sql &= &\" where {col.name} = {{{valName}.primKey}}\"\n"
        break
    res &= "  db.exec(sql.sql)\n"

    res &= &"proc update{tableCls}*(db: DbConn, {valName}Seq: seq[{tableCls}]) =\n"
    res &= &"  for {valName} in {valName}Seq:\n"
    res &= &"    db.update{tableCls}({valName})\n"

  block dumpTable:
    res &= &"proc dump{tableCls}*(db: DbConn, dirName = \"csv\") =\n"
    res &= "  dirName.createDir\n"
    res &= "  let\n"
    res &= &"    fileName = dirName / \"{tableName}.csv\"\n"
    res &= "    f = fileName.open(fmWrite)\n"
    res &= "  f.writeLine(\""
    for col in cols:
      res &= col.name & ","
    res[^1] = '"'
    res &= ")\n"
    res &= &"  for row in db.select{tableCls}:\n"
    for col in cols:
      case col.dataType.toLowerAscii
      of boolType:
        res &= &"    if row.{col.name}:\n"
        res &= "      f.write(\"1,\")\n"
        res &= "    else:\n"
        res &= "      f.write(\"0,\")\n"
      of dateType:
        res &= &"    f.write(row.{col.name}.format(\""
        case col.dataType.toLowerAscii
        of "date":
          res &= DateFormat
        of "datetime":
          res &= DateTimeFormat
        res &= "\"), ',')\n"
      else:
        res &= &"    f.write('\"', $row.{col.name}, '\"', ',')\n"
    res &= "    f.setFilePos(f.getFilePos - 1)\n"
    res &= "    f.writeLine(\"\")\n"
    res &= "  f.close\n"

  block insertCsv:
    res &= &"proc insertCsv{tableCls}*(db: DbConn, fileName: string) =\n"
    res &= "  var parser: CsvParser\n"
    res &= "  defer: parser.close\n"
    res &= "  parser.open(fileName)\n"
    res &= "  parser.readHeaderRow\n"
    res &= "  while parser.readRow:\n"
    res &= &"    var data: {tableCls}\n"
    for col in cols:
      res &= &"    data.setData{tableCls}(\"{col.name}\", parser.rowEntry(\"{col.name}\"))\n"
    res &= &"    db.insert{tableCls}(data)\n"

  block restoreTable:
    res &= &"proc restore{tableCls}*(db: DbConn, dirName = \"csv\") =\n"
    res &= &"  let fileName = dirName / \"{tableName}.csv\"\n"
    res &= &"  db.exec(\"delete from {tableName}\".sql)\n"
    res &= &"  db.insertCsv{tableCls}(fileName)\n"

  let
    dir = fileName.parentDir
    name = fileName.extractFilename.toCamelCase.changeFileExt(".nim")
  writeFile(dir / name, res)

proc makeNimFile*(conf: DbConf, pkgDir: string) =
  ## make nim file from table csv
  var nimFiles: seq[string]
  for f in walkFiles(pkgDir / CsvDir / "*.csv"):
    if f == pkgDir / CsvDir / SampleCsv:
      continue
    f.readCsv(conf)
    nimFiles.add(f.extractFilename.replace(".csv").toCamelCase)

  var res: string
  res = "import\n  "
  case conf.dbType
  of sqlite:
    res &= "db_sqlite"
  of mysql:
    res &= "db_mysql"
    if conf.dbPass == "":
      res &= ",\n  terminal"
  res &= ",\n  " & CsvDir & " / [" & nimFiles.join(", ") & "]\n"
  res &= "export\n  "
  case conf.dbType
  of sqlite:
    res &= "db_sqlite"
  of mysql:
    res &= "db_mysql"
  res &= ",\n  " & nimFiles.join(", ") & "\n"
  res &= "proc openDb*(): DbConn =\n"
  if conf.dbType == mysql and conf.dbPass == "":
    res &= &"  let passwd = readPasswordFromStdin(\"database password(user: {conf.dbUser}): \")\n"
  res &= "  let db = open("
  case conf.dbType
  of sqlite:
    res &= '"' & conf.dbFileName & "\", \"\", \"\", \"\""
  of mysql:
    res &= '"' & conf.dbHost & "\","
    res &= '"' & conf.dbUser & "\","
    if conf.dbPass != "":
      res &= '"' & conf.dbPass & "\","
    else:
      res &= "passwd,"
    res &= '"' & conf.dbName & '"'
  res &= ")\n"
  if conf.dbType == mysql:
    res &= "  discard db.setEncoding(\"utf8\")\n"
  res &= "  return db\n"
  res &= "proc createTables*(db: DbConn) =\n"
  for f in nimFiles:
    res &= &"  db.create{f.toCamelCase(true)}Table\n"

  writeFile(pkgDir / ParentFile, res)
