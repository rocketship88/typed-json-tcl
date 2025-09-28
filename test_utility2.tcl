# stitch together with utilities and parser for testing
# Test JSON data with arrays
set testJson {
{
  "users": ["Alice", "Bob", "Charlie"],
  "servers": {
    "ports": [80, 443, 8080],
    "names": ["web1", "web2"]
  },
  "settings": {
    "enabled": true,
    "timeout": 30
  }
}
}

# Only run tests if no_insert_tests is not set
if {![info exists no_insert_tests]} {

if {1} {
puts "=== Testing insertIntoArrayAtPath Function ==="
puts ""

# Parse the test JSON
set testData [typed_json::json2dict $testJson]
puts "Original data:"
puts [typed_json::asJson $testData "  "]
puts ""

# Test 1: Insert at beginning of array (index 0)
puts "Test 1: Insert at beginning of users array (index 0)"
set result1 [insertIntoArrayAtPath $testData "users" 0 {STRING "NewUser"}]
puts "Result: [typed_json::asJson [typed_json::getPath $result1 users]]"
puts ""

# Test 2: Insert at specific middle position (index 2)
puts "Test 2: Insert at position 2 in users array"
set result2 [insertIntoArrayAtPath $testData "users" 2 {STRING "MiddleUser"}]
puts "Result: [typed_json::asJson [typed_json::getPath $result2 users]]"
puts ""

# Test 3: Insert at end using "end"
puts "Test 3: Insert at end using 'end'"
set result3 [insertIntoArrayAtPath $testData "users" end {STRING "LastUser"}]
puts "Result: [typed_json::asJson [typed_json::getPath $result3 users]]"
puts ""

# Test 4: Insert using "end-1" (before last element)
puts "Test 4: Insert before last element using 'end-1'"
set result4 [insertIntoArrayAtPath $testData "users" end-1 {STRING "BeforeLastUser"}]
puts "Result: [typed_json::asJson [typed_json::getPath $result4 users]]"
puts ""

# Test 5: Insert complex typed value (object)
puts "Test 5: Insert complex object into users array"
set newUser {OBJECT {name {STRING "ComplexUser"} age {NUMBER "25"} active "TRUE"}}
set result5 [insertIntoArrayAtPath $testData "users" 1 $newUser]
puts "Result: [typed_json::asJson [typed_json::getPath $result5 users] {  }]"
puts ""

# Test 6: Insert into nested array path
puts "Test 6: Insert into nested array (servers.ports)"
set result6 [insertIntoArrayAtPath $testData "servers.ports" 1 {NUMBER "3000"}]
puts "Result: [typed_json::asJson [typed_json::getPath $result6 servers.ports]]"
puts ""

# Error handling tests
puts "=== Error Handling Tests ==="

# Test 7: Invalid index format
puts "Test 7: Invalid index format"
if {[catch {insertIntoArrayAtPath $testData "users" "invalid" {STRING "test"}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 8: Path doesn't point to array
puts "Test 8: Path doesn't point to array"
if {[catch {insertIntoArrayAtPath $testData "settings.enabled" 0 {STRING "test"}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 9: Invalid typed value
puts "Test 9: Invalid typed value"
if {[catch {insertIntoArrayAtPath $testData "users" 0 {BADTYPE "test"}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 10: Non-existent path
puts "Test 10: Non-existent path"
if {[catch {insertIntoArrayAtPath $testData "nonexistent" 0 {STRING "test"}} err]} {
    puts "Error (expected): $err"
}
puts ""

} ;# end if {0} - insertIntoArrayAtPath tests

if {1} {
puts "=== Testing insertJsonIntoArrayAtPath Function ==="
puts ""

# Parse the test JSON
set testData [typed_json::json2dict $testJson]
puts "Original data:"
puts [typed_json::asJson $testData "  "]
puts ""

# Test 1: Insert simple JSON string at beginning
puts "Test 1: Insert simple JSON string at beginning"
set result1 [insertJsonIntoArrayAtPath $testData "users" 0 {"JsonUser"}]
puts "Result: [typed_json::asJson [typed_json::getPath $result1 users]]"
puts ""

# Test 2: Insert JSON number into ports array
puts "Test 2: Insert JSON number into ports array"
set result2 [insertJsonIntoArrayAtPath $testData "servers.ports" 1 {9000}]
puts "Result: [typed_json::asJson [typed_json::getPath $result2 servers.ports]]"
puts ""

# Test 3: Insert complex JSON object
puts "Test 3: Insert complex JSON object"
set jsonObject {{"name": "JsonUser", "age": 30, "active": true}}
set result3 [insertJsonIntoArrayAtPath $testData "users" end $jsonObject]
puts "Result: [typed_json::asJson [typed_json::getPath $result3 users] {  }]"
puts ""

# Test 4: Insert JSON array into users (nested array)
puts "Test 4: Insert JSON array into users"
set jsonArray {["item1", "item2", "item3"]}
set result4 [insertJsonIntoArrayAtPath $testData "users" 1 $jsonArray]
puts "Result: [typed_json::asJson [typed_json::getPath $result4 users] {  }]"
puts ""

# Test 5: Insert JSON boolean
puts "Test 5: Insert JSON boolean"
set result5 [insertJsonIntoArrayAtPath $testData "users" end-1 {false}]
puts "Result: [typed_json::asJson [typed_json::getPath $result5 users]]"
puts ""

# Error handling tests
puts "=== Error Handling Tests ==="

# Test 6: Invalid JSON
puts "Test 6: Invalid JSON syntax"
if {[catch {insertJsonIntoArrayAtPath $testData "users" 0 {invalid json}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 7: Invalid index format
puts "Test 7: Invalid index format"
if {[catch {insertJsonIntoArrayAtPath $testData "users" "bad" {"test"}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 8: Path is not an array
puts "Test 8: Path is not an array"
if {[catch {insertJsonIntoArrayAtPath $testData "settings.enabled" 0 {"test"}} err]} {
    puts "Error (expected): $err"
}
puts ""

} ;# end if {1} - insertJsonIntoArrayAtPath tests

} ;# end if no_insert_tests
