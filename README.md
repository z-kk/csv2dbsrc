# csv2db
create db util source from csv

# How to use csv2dbsrc

## Use in Nim project directory

first, exec `csv2dbsrc`

```
$ csv2dbsrc
select database type
1: sqlite
2: mysql
>> 1
input database file name
>> test.db
make database table csv referencing path/to/sample.csv
```

then copy and modify sample.csv in same directory.  
the csv file name should be the table name.

sample.csv
|name|comment|data\_type|default\_val|not\_null|is\_primary|
----|----|----|----|----|----
|id|user id|INTEGER||1|1|
|user\_name|user name|TEXT||1||
|address||TEXT||||
|tel||TEXT|'000-0000-0000'|||
|group\_id|user's group id|INTEGER|1|1||
|updated\_at|updated date time|DATETIME|'9999-12-31'|1||

then exec `csv2dbsrc` again to make `dbtables.nim` and each `tableName.nim` file.

## Made files usage

import `dbtables` in your own source.

### openDb\*

```nim
proc openDb*(): DbConn =
```

### createTables\*

```nim
proc createTables*(db: DbConn) =
```

exec `createTableNameTable` each tables.

### type

```nim
TableNameCol* = enum
```

table column names.

```nim
TableNameTable* = object
```

table object.

### setDataTableNameTable\*

```nim
proc setDataTableNameTable*(data: var TableNameTable, colName, value: string) =
```

set value to TableNameTable object by string.

### createTableNameTable\*

```nim
proc createTableNameTable*(db: DbConn) =
```

exec `create table if not exists table_name`

### insertTableNameTable\*

```nim
proc insertTableNameTable*(db: DbConn, rowData: TableNameTable) =
```

exec `insert into table_name`

### insertTableNameTable\*

```nim
proc insertTableNameTable*(db: DbConn, rowDataSeq: seq[TableNameTable]) =
```

exec `insert into table_name` for each rowData.

### selectTableNameTable\*

```nim
proc selectTableNameTable*(db: DbConn, whereStr = "", orderStr = ""): seq[TableNameTable] =
```

exec `select * from table_name` and return the result.

### updateTableNameTable\*

```nim
proc updateTableNameTable*(db: DbConn, rowData: TableNameTable) =
```

exec `update table_name`  
rowData must be got by selectTableNameTable and table must have primary key.

### updateTableNameTable\*

```nim
proc updateTableNameTable*(db: DbConn, rowDataSeq: seq[TableNameTable]) =
```

exec `update table_name` for each rowData.

### dumpTableNameTable\*

```nim
proc dumpTableNameTable*(db: DbConn, dirName = "csv") =
```

make db table data csv.

### insertCsvTableNameTable\*

```nim
proc insertCsvTableNameTable*(db: DbConn, fileName: string) =
```

insert rows from fileName csv. this proc not check exists rows.

### restoreTableNameTable\*

```nim
proc restoreTableNameTable*(db: DbConn, dirName = "csv") =
```

drop table and make table by data csv.

# Pull Request please

Test for mysql is not enough.

If you can use Japanese, please make pull request in Japanese!
