# Sort Assignment — Teacher Repo

## Assignment
Students must implement a C program that reads N integers from stdin and prints them sorted in ascending order, one per line.

## Input format
```
N
a1
a2
...
aN
```

## Tests

| Test | Description |
|------|-------------|
| `01_basic` | 5 positive integers with a duplicate |
| `02_negatives` | Mix of negative and positive integers |
| `03_single` | Edge case — single element |
| `04_duplicates` | All elements are the same |
| `05_timeout` | 10,000 integers — catches O(n²) solutions |

## Adding tests
Create a new directory under `tests/` with:
- `input.txt` — stdin fed to the student binary
- `expected.txt` — expected stdout output

## Test script
`run_tests.sh <student_repo_path>` — outputs JSON to stdout.
