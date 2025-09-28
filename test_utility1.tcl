# stitch together with parser and utilities for testing
# Test JSON configuration
set configJson {
{
  "server": {
    "host": "localhost",
    "port": 8080,
    "ssl": false
  },
  "database": {
    "host": "db.example.com",
    "port": 5432,
    "name": "myapp"
  },
  "features": {
    "logging": true,
    "debug": false
  }
}
}

# Only run tests if no_put_tests is not set
if {![info exists no_put_tests]} {

puts "=== Testing setObjectByPath Function ==="
puts ""

# Parse the JSON
# puts "Original configuration:"
set config [typed_json::json2dict $configJson]
# puts [typed_json::asJson $config "  "]
# puts ""

# Test 1: Change server host
puts "Test 1: Changing server.host to 'production.server.com'"
set config1 [setObjectByPath $config "server.host" [list "STRING" "production.server.com"]]
puts "New server.host: [typed_json::getValue [typed_json::getPath $config1 server.host]]"
puts ""

# Test 2: Change server port
puts "Test 2: Changing server.port to 443"
set config2 [setObjectByPath $config1 "server.port" [list "NUMBER" "443"]]
puts "New server.port: [typed_json::getValue [typed_json::getPath $config2 server.port]]"
puts ""

# Test 3: Enable SSL
puts "Test 3: Enabling SSL"
set config3 [setObjectByPath $config2 "server.ssl" "TRUE"]
puts "New server.ssl: [typed_json::getValue [typed_json::getPath $config3 server.ssl]]"
puts ""

# Test 4: Change database name
puts "Test 4: Changing database.name to 'production_db'"
set config4 [setObjectByPath $config3 "database.name" [list "STRING" "production_db"]]
puts "New database.name: [typed_json::getValue [typed_json::getPath $config4 database.name]]"
puts ""

# Test 5: Disable debug mode
puts "Test 5: Disabling debug mode"
set config5 [setObjectByPath $config4 "features.debug" "FALSE"]
puts "New features.debug: [typed_json::getValue [typed_json::getPath $config5 features.debug]]"
puts ""

# Show final configuration
puts "=== Final Configuration ==="
puts [typed_json::asJson $config5 "  "]
puts ""

# Test error handling
puts "=== Error Handling Tests ==="

# Test 6: Try to set non-existent path
puts "Test 6: Attempting to set non-existent path 'server.timeout'"
if {[catch {setObjectByPath $config5 "server.timeout" [list "NUMBER" "30"]} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 7: Try to set path on non-object
puts "Test 7: Attempting to set path on a non-object (server.host.invalid)"
if {[catch {setObjectByPath $config5 "server.host.invalid" [list "STRING" "test"]} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 8: Attempting to use setObjectByPath on structure containing array
puts "Test 8: Attempting to use setObjectByPath on structure containing array"
set arrayJson {{"users": ["Alice", "Bob"], "count": 2}}
set arrayData [typed_json::json2dict $arrayJson]
if {[catch {setObjectByPath $arrayData "users.0" [list "STRING" "Charlie"]} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 9: Attempting to use invalid typed value
puts "Test 9: Attempting to set invalid typed value"
if {[catch {setObjectByPath $config5 "server.host" {INVALID_TYPE "test"}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 10: Attempting to use malformed typed value
puts "Test 10: Attempting to set malformed typed value {abc def}"
if {[catch {setObjectByPath $config5 "server.host" {abc def}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 11: Attempting to use invalid single token
puts "Test 11: Attempting to set invalid single token 'invalid'"
if {[catch {setObjectByPath $config5 "server.ssl" "invalid"} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 12: Valid single token values (should work)
puts "Test 12: Testing valid single token values"
set config12a [setObjectByPath $config5 "server.ssl" "TRUE"]
puts "Set TRUE: [typed_json::getValue [typed_json::getPath $config12a server.ssl]]"
set config12b [setObjectByPath $config12a "server.ssl" "FALSE"]
puts "Set FALSE: [typed_json::getValue [typed_json::getPath $config12b server.ssl]]"
puts ""

# Test 13: Type changes - replacing simple values with complex types
puts "Test 13: Type changes - replacing simple values with complex types"

# Test 13a: Replace a string with an object
puts "Test 13a: Replacing server.host (string) with an object"
set config13a [setObjectByPath $config12b "server.host" [list "OBJECT" {primary {STRING "production.server.com"} backup {STRING "backup.server.com"}}]]
puts "New server.host structure: [typed_json::asJson [typed_json::getPath $config13a server.host]]"
puts ""

# Test 13b: Replace a number with an array
puts "Test 13b: Replacing server.port (number) with an array of ports"
set config13b [setObjectByPath $config13a "server.port" [list "ARRAY" {{NUMBER "443"} {NUMBER "8443"} {NUMBER "9443"}}]]
puts "New server.port structure: [typed_json::asJson [typed_json::getPath $config13b server.port]]"
puts ""

# Test 13c: Replace a boolean with a complex nested object
puts "Test 13c: Replacing server.ssl (boolean) with a complex SSL config object"
set sslConfig [list "OBJECT" {
    enabled "TRUE"
    certificate {STRING "/path/to/cert.pem"}
    key {STRING "/path/to/key.pem"}
    protocols {ARRAY {{STRING "TLSv1.2"} {STRING "TLSv1.3"}}}
}]
set config13c [setObjectByPath $config13b "server.ssl" $sslConfig]
puts "New server.ssl structure: [typed_json::asJson [typed_json::getPath $config13c server.ssl] {  }]"
puts ""

# Test 13d: Replace a string using json text
puts "Test 13d: Replacing database.host (string) with json string"
set config13d [setJsonObjectByPath $config13b "database.host" {"db.example.me"}]
puts "New database.host: [typed_json::getValue [typed_json::getPath $config13d database.host]]"
puts ""

# Test 13e: Replace with complex JSON object
puts "Test 13e: Replacing database.name with complex JSON object"
set complexJson {{"primary": "prod_db", "backup": "backup_db", "replicas": 3}}
set config13e [setJsonObjectByPath $config13d "database.name" $complexJson]
puts "New database.name structure: [typed_json::asJson [typed_json::getPath $config13e database.name]]"
puts ""

# Test JSON error handling
puts "=== JSON Error Handling Tests ==="

# Test 15a: Invalid JSON syntax
puts "Test 15a: Invalid JSON syntax"
if {[catch {setJsonObjectByPath $config13e "server.host" {invalid json}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 15b: JSON parsing succeeds but path doesn't exist
puts "Test 15b: Valid JSON but non-existent path"
if {[catch {setJsonObjectByPath $config13e "nonexistent.path" {"valid json"}} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 14: Malformed data validation tests
puts "Test 14: Malformed data validation tests"

# Test 14a: Invalid NUMBER data
puts "Test 14a: Attempting to set invalid NUMBER data"
if {[catch {setObjectByPath $config13c "database.port" [list "NUMBER" "not-a-number"]} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 14b: Invalid OBJECT data (not a valid dict)
puts "Test 14b: Attempting to set invalid OBJECT data (malformed dict)"
if {[catch {setObjectByPath $config13c "server.host" [list "OBJECT" {key1 value1 key2}]} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 14c: Invalid ARRAY data (contains invalid typed elements)
puts "Test 14c: Attempting to set ARRAY with invalid typed elements"
if {[catch {setObjectByPath $config13c "server.port" [list "ARRAY" {{INVALID_TYPE "data"} {STRING "valid"}}]} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 14d: Nested invalid data in OBJECT
puts "Test 14d: Attempting to set OBJECT with nested invalid data"
if {[catch {setObjectByPath $config13c "features" [list "OBJECT" {
    logging "TRUE"
    debug {NUMBER "invalid-number"}
    metrics {BADTYPE "data"}
}]} err]} {
    puts "Error (expected): $err"
}
puts ""

# Test 14e: Deeply nested invalid data
puts "Test 14e: Attempting to set deeply nested structure with invalid data"
if {[catch {setObjectByPath $config13c "database" [list "OBJECT" {
    connection {OBJECT {
        host {STRING "db.example.com"}
        settings {ARRAY {{STRING "setting1"} {INVALID "bad"}}}
    }}
}]} err]} {
    puts "Error (expected): $err"
}
puts ""

puts "=== Performance Test ==="
puts "Running 10 rounds of 1000 setObjectByPath operations each..."
puts "Testing with ALL NO-OPS (same value repeatedly)..."
set configPerf $config5
set totalTime 0
for {set round 1} {$round <= 10} {incr round} {
    set i 0
    set timing [time {
        incr i  ;# Still increment for verification
        set configPerf [setObjectByPath $configPerf "server.port" [list "NUMBER" "9000"]]
    } 1000]
    set microsPerOp [lindex [split $timing] 0]
    set totalTime [expr {$totalTime + $microsPerOp}]
    # puts "Round $round: $timing"
    # puts "Final port value after round $round: [typed_json::getValue [typed_json::getPath $configPerf server.port]]"
    # puts "Final i value: $i"
}
set avgTime [expr {$totalTime / 10.0}]
puts "Average: $avgTime microseconds per iteration"

puts ""
puts "=== Global Variables Debug ==="
catch {lg ** | 999}

puts ""
puts "=== Testing namespace import ==="
namespace import typed_json::*

}

