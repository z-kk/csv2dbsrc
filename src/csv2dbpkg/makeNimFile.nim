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
  intType = ["integer", "int", "tinyint", "smallint", "mediumint", "bigint", "boolean"]
  floatType = ["real", "float", "double", "decimal", "numeric"]
  dateType = ["date", "datetime"]

proc toValueString(col: ColumnInfo, valName: string): string =
  ## make string to match ColumnInfo
  result = valName & "." & col.name
  case col.dataType.toLowerAscii
  of intType, floatType:
    result = "{" & result & "}"
  of dateType:
    case col.dataType.toLowerAscii
    of "date":
      result &= &".format({DateFormat})"
      result = "date('{" & result & "}')"
    of "datetime":
      result &= &".format({DateTimeFormat})"
      result = "datetime('{" & result & "}')"
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
  res &= "  strformat,\n  "
  case conf.dbType
  of sqlite:
    res &= "db_sqlite"
  of mysql:
    res &= "db_mysql"

  res &= "\ntype\n  "
  res &= tableCls & "* = object\n"
  for col in cols:
    res &= &"    {col.name}*: "
    case col.dataType.toLowerAscii
    of intType:
      res &= "int"
    of floatType:
      res &= "float"
    of dateType:
      res &= "DateTime"
    else:
      res &= "string"
    res &= "\n"

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

  writeFile(fileName.toCamelCase.changeFileExt(".nim"), res)

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
  res &= "  return open("
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
  res &= "proc createTables*(db: DbConn) =\n"
  for f in nimFiles:
    res &= &"  db.create{f.toCamelCase(true)}Table\n"

  writeFile(pkgDir / ParentFile, res)
