#!/usr/bin/env bash
set -euo pipefail


TEST_PORT=8080

# Test helpers
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"
    
    if [[ "$actual" != "$expected" ]]; then
        echo "❌ Assertion failed: $message"
        echo "Expected: $expected"
        echo "Actual:   $actual"
        return 1
    fi
    echo "✅ $message"
    return 0
}

assert_status() {
    local expected="$1"
    local url="$2"
    local method="${3:-GET}"
    local data="${4:-}"
    
    local status
    if [[ -n "$data" ]]; then
        status=$(curl -s -X "$method" -w "%{http_code}" -d "$data" "http://localhost:$TEST_PORT/$url" -o /dev/null)
    else
        status=$(curl -s -X "$method" -w "%{http_code}" "http://localhost:$TEST_PORT/$url" -o /dev/null)
    fi
    
    assert_equals "$expected" "$status" "$method $url -> $expected"
}

# Create test files
echo "Hello World" > "htdocs/hello.txt"
echo '#!/bin/sh
echo "Script output"' > "htdocs/test.sh"
chmod +x "htdocs/test.sh"

# Test cases
echo "Running tests..."

# GET tests
assert_status "200" "hello.txt"
assert_equals "Hello World" "$(curl -s http://localhost:$TEST_PORT/hello.txt)" "GET hello.txt content"
assert_status "404" "nonexistent.txt"

# POST tests
assert_status "200" "test.sh" "POST"
assert_equals "Script output" "$(curl -s -X POST http://localhost:$TEST_PORT/test.sh)" "POST test.sh execution"
assert_status "404" "nonexistent.sh" "POST"

# PUT tests
assert_status "201" "newfile.txt" "PUT" "New content"
assert_equals "New content" "$(cat htdocs/newfile.txt)" "PUT file content verification"

# PATCH tests
echo "original" > "htdocs/patchme.txt"
assert_status "200" "patchme.txt" "PATCH" "0a1\n> patched"
assert_equals $'original\npatched' "$(cat htdocs/patchme.txt)" "PATCH file modification"

# DELETE tests
touch "htdocs/deleteme.txt"
assert_status "200" "deleteme.txt" "DELETE"
test ! -f "htdocs/deleteme.txt" && echo "✅ DELETE file removed" || echo "❌ DELETE file still exists"

echo "All tests completed!"
