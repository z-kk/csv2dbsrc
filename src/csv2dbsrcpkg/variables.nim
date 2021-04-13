type
  DbType* = enum
    sqlite = 1,
    mysql

  JsonKey* = enum
    dbType,
    dbFileName,
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

  DbConf* = object
    dbType*: DbType  ## database type
    dbFileName*: string  ## database file name (sqlite)
    dbHost*: string  ## database host name
    dbUser*: string  ## database user name
    dbPass*: string  ## database password (not saved)
    dbName*: string  ## dbname

const
  DbConfFile* = "dbConf.json"
  CsvDir* = "csvDir"
  SampleCsv* = "sample.csv"
