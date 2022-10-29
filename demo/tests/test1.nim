import unittest

import
  std / [os, times]

import demo {.all.}
import demopkg/dbtables
suite "db test":
  createConfDir()
  let db = openDb()
  defer:
    db.close
    getDbFileName().removeFile

  let user = "test_user"

  test "create tables":
    db.createTables

  test "insert row":
    var row: TestTableTable
    row.user_name = user
    row.grade = 50
    row.updated_at = now()
    db.insertTestTableTable(row)

    row.user_name = "other_user"
    row.grade = 30
    db.insertTestTableTable(row)

  test "select rows":
    var rows = db.selectTestTableTable("user_name = ?", @[], user)
    check rows.len > 0
    for row in rows:
      check row.grade == 50

    rows = db.selectTestTableTable(orderBy = @["grade"])
    check rows.len > 0
    check rows[0].grade == 30

  test "update row":
    var rows = db.selectTestTableTable("user_name = ?", @[], user)
    check rows.len > 0
    for r in rows:
      var row = r
      row.grade = 25
      db.updateTestTableTable(row)

    rows = db.selectTestTableTable(orderBy = @["grade"])
    check rows.len > 0
    check rows[0].grade == 25
