type
  DbType* = enum
    sqlite = 1,
    mysql

  JsonKey* = enum
    dbType,
    dbFileName,
    dbDirName,
    dbHost,
    dbUser,
    dbPass,
    dbName

  CsvTitles* = enum
    name,
    comment,
    data_type,
    length,
    default_val,
    not_null,
    is_primary

  DirType* = enum
    dtXdgConfig = "XDG_CONFIG_HOME",
    dtXdgData = "XDG_DATA_HOME",
    dtSameDir = "current Dir(./)",
    dtElse = "else"

  DbConf* = object
    dbType*: DbType  ## database type
    dbFileName*: string  ## database file name (sqlite)
    dbDirName*: string ## database dir name (sqlite)
    dbHost*: string  ## database host name
    dbUser*: string  ## database user name
    dbPass*: string  ## database password (not saved)
    dbName*: string  ## dbname

const
  DbConfFile* = "dbConf.json"
  CsvDir* = "csvDir"
  SampleCsv* = "sample.csv"
