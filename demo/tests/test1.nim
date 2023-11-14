import unittest

import
  std / [times]

when defined(sqlite):
  import
    std / [os]
when defined(usePass):
  const Passwd {.strdefine.} = ""

import demopkg/dbtables
suite "db test":
  test "create tables":
    when defined(usePass):
      createTables(Passwd)
    else:
      createTables()

  when defined(usePass):
    let db = openDb(Passwd)
  else:
    let db = openDb()
  defer:
    db.exec("drop table testTable".sql)
    db.close
    when defined(sqlite):
      getDbFileName().removeFile

  let user = "test_user"

  test "insert row":
    var row: TestTableTable
    row.user_name = user
    row.grade = 50
    row.is_enabled = true
    row.updated_at = now()
    db.insertTestTableTable(row)

    row.user_name = "other_user"
    row.grade = 30
    check db.tryInsertTestTableTable(row) > 1

  test "select rows":
    var rows = db.selectTestTableTable("user_name = ?", @["id"], user)
    check rows.len > 0
    for row in rows:
      check row.grade == 50
      check row.is_enabled

    rows = db.selectTestTableTable(orderBy = @["grade"])
    check rows.len > 0
    check rows[0].grade == 30

  test "update row":
    var rows = db.selectTestTableTable("user_name = ?", user)
    check rows.len > 0
    for r in rows:
      var row = r
      row.grade = 25
      db.updateTestTableTable(row)

    rows = db.selectTestTableTable(orderBy = @["grade"])
    check rows.len > 0
    check rows[0].grade == 25
