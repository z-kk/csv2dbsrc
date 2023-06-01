import
  strutils

proc toCamelCase*(s: string, upperHeadChar = false): string =
  ## convert string to camel case
  if s == "":
    return
  var
    i = -1
    j = s.find('_')
  while j > -1:
    result &= s[i + 1 ..< i + j + 1].capitalizeAscii
    i.inc(j + 1)
    j = s[i + 1 .. ^1].find('_')
  result &= s[i + 1 .. ^1].capitalizeAscii
  if not upperHeadChar:
    result[0] = result[0].toLowerAscii
