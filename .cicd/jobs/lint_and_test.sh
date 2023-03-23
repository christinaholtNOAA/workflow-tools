#!/bin/bash

#Install uwtools
pip install -e .

# Check for pytest and pylint
for pkg in pytest pylint ; do
  if hash $pkg  2>/dev/null; then
    echo "$pkg installed, moving on!".
  else
    echo "$pkg is not installed"
    exit 1
  fi
done

# Run tests
pytest | tee -a ${WORKSPACE}/results.txt
status=${PIPESTATUS[0]}
test $status -eq 0 || ( echo "pytest failed" && exit 1 )

# Lint
pylint tests
status=$?
test $status -eq 0 || ( echo "linting tests failed" && exit 1 )

cd ${WORKSPACE}/src
pylint uwtools
status=$?
test $status -eq 0 || ( echo "linting tools failed" && exit 1 )
