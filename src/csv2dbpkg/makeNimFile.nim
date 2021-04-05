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
  intType = ["integer", "int", "tinyint", "smallint", "mediumint", "bigint", "boolean"]
  floatType = ["real", "float", "double", "decimal", "numeric"]
  dateType = ["date", "datetime"]

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
      col.length = cp.rowEntry($length).parseInt
    col.defaultVal = cp.rowEntry($default_val)
    col.notNull = cp.rowEntry($not_null) notin ["", "0"]
    col.isPrimary = cp.rowEntry($is_primary) notin ["", "0"]
    cols.add(col)

  let tableName = fileName.extractFilename.replace(".csv")
  var res: string = "import\n  "
  case conf.dbType
  of sqlite:
    res &= "db_sqlite"
  of mysql:
    res &= "db_mysql"

  res &= "\ntype\n  "
  res &= tableName.toCamelCase(true) & "Table* = object\n"
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

  res &= "proc create" & tableName.toCamelCase(true) & "Table*(db: DbConn) =\n"
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
      res &= &" comment '{col.comment}'"
    res &= ",\n"
  res = res[0..^3] & "\n  )\"\"\".sql\n"
  res &= "  db.exec(sql)"

  writeFile(fileName.toCamelCase.replace(".csv", ".nim"), res)

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
  res &= ",\n  " & CsvDir & " / [" & nimFiles.join(", ") & "]\n"
  res &= "export\n  "
  case conf.dbType
  of sqlite:
    res &= "db_sqlite"
  of mysql:
    res &= "db_mysql"
  res &= "\n,  " & nimFiles.join(", ") & "\n"
  res &= "proc openDb*(): DbConn =\n"
  res &= "  return open("
  case conf.dbType
  of sqlite:
    res &= '"' & conf.dbFileName & "\", \"\", \"\", \"\""
  of mysql:
    res &= '"' & conf.dbHost & "\","
    res &= '"' & conf.dbUser & "\","
    res &= '"' & conf.dbPass & "\","
    res &= '"' & conf.dbName & '"'
  res &= ")\n"
  res &= "proc createTables*(db: DbConn) =\n"
  for f in nimFiles:
    res &= &"  db.create{f.toCamelCase(true)}Table\n"

  writeFile(pkgDir / ParentFile, res)
