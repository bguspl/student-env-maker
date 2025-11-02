#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "--- C++ ---"
if command -v g++ >/dev/null 2>&1; then
  g++ -std=c++17 hello.cpp -o hello
  ./hello
else
  echo "g++ not found"
fi

echo "\n--- Java ---"
if command -v javac >/dev/null 2>&1; then
  javac Hello.java
  java Hello
else
  echo "javac not found"
fi

echo "\n--- Python ---"
if command -v python3.12 >/dev/null 2>&1; then
  python3.12 hello.py
elif command -v python3 >/dev/null 2>&1; then
  python3 hello.py
else
  echo "Python not found"
fi

echo "\n--- SQLite ---"
if command -v sqlite3 >/dev/null 2>&1; then
  sqlite3 test.db <<'SQL'
CREATE TABLE IF NOT EXISTS people(id INTEGER PRIMARY KEY, name TEXT);
INSERT INTO people(name) VALUES('alice'), ('bob');
SELECT id, name FROM people;
SQL
else
  echo "sqlite3 not found"
fi

echo "\nDone."
