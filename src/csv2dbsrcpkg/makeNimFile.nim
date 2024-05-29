import
  os, strutils, strformat, sequtils, parsecsv,
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
  of intType, floatType:
    result = "$" & result
  of boolType:
    result = "if " & result & ": \"1\" else: \"0\""
  of "date":
    result &= &".format(\"{DateFormat}\")"
  of "datetime":
    result &= &".format(\"{DateTimeFormat}\")"

proc readCsv(fileName: string, conf: DbConf) =
  ## read csv file and make nim file
  include "tmpl/tablefile.nimf"

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
    dir = fileName.parentDir
    name = fileName.extractFilename.toCamelCase.changeFileExt(".nim")

  writeFile(dir / name, tableFile(conf, fileName, cols))

proc makeNimFile*(conf: DbConf, pkgDir: string) =
  ## make nim file from table csv
  include "tmpl/parentfile.nimf"

  var nimFiles: seq[string]
  for f in walkFiles(pkgDir / CsvDir / "*.csv"):
    if f == pkgDir / CsvDir / SampleCsv:
      continue
    f.readCsv(conf)
    nimFiles.add(f.extractFilename.replace(".csv").toCamelCase)

  writeFile(pkgDir / ParentFile, parentFile(conf, nimFiles))
