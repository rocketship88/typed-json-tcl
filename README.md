# typed-json - Pure Tcl JSON Parser with Type Preservation

A pure Tcl JSON parser that preserves complete type information, similar to tDOM's `-json` option but without requiring binary extensions. Includes two implementations optimized for different use cases.

## Features

- **Pure Tcl implementation** - no binary dependencies required
- **Type preservation** - maintains JSON type information for accurate round-trip conversion
- **Flask-based lexing** - demonstrates advanced Tcl parsing techniques
- **Comprehensive error handling** - clear error messages for invalid JSON
- **Unicode support** - handles escape sequences and surrogate pairs
- **Utility functions** - convenient methods for working with parsed data
- **JSON5 support** - optional comment parsing (single-line `//` and multi-line `/* */`)

## Two Implementations

### jsonparser.tcl (Dict-based)
- Uses Tcl's `dict` for objects - efficient O(1) key lookups
- "Last wins" behavior for duplicate keys (standard JSON parser behavior)
- Mixed dict/list operations (some shimmering between representations)
- **Best for**: General JSON processing, APIs, performance-critical applications

### jsonparser-list.tcl (List-based) 
- Uses pure list operations throughout - eliminates representation shimmering
- Preserves duplicate keys in order (tDOM compatible)
- O(n) key lookups for objects
- **Best for**: tDOM compatibility, duplicate key preservation, maximum compatibility

## Quick Start

### Running Standalone Tests
```bash
# Test the dict-based version
tclsh jsonparser.tcl

# Test the list-based version  
tclsh jsonparser-list.tcl
```

### Using as a Library
```tcl
# Skip built-in tests when sourcing
set no_tests 1
source jsonparser.tcl

# Parse JSON with type information preserved
set data [typed_json::json2dict {{"name": "Alice", "age": 30}}]
puts $data
# Output: OBJECT {name {STRING Alice} age {NUMBER 30}}

# Extract values
puts [typed_json::getValue [typed_json::getPath $data "name"]]
# Output: Alice
```

## JSON Utilities (Optional)

The `jsonutilities.tcl` file provides path-based manipulation functions that work with the **dict-based parser only**. These utilities use dot notation for path navigation (e.g., "server.host.primary").

### Key Functions
- **`setObjectByPath`** - Modify existing object values using path notation
- **`insertIntoArrayAtPath`** - Insert values into arrays at specific indices  
- **`setJsonObjectByPath`** - Set object values using raw JSON text
- **`insertJsonIntoArrayAtPath`** - Insert JSON text into arrays

### Path Delimiter Configuration
The default path delimiter is `"."`. To change it to a single character:
```tcl
namespace eval typed_json {set pathDelimiter "/"}
# Now use paths like "server/host/primary"
```

### Usage Options
You can use the utilities in several ways:
- **Source the file**: `source jsonutilities.tcl`
- **Copy functions into your code** for customization
- **Append to your local copy** of `jsonparser.tcl` (if creating a module)

### Example Usage
```tcl
# Load both parser and utilities
set no_tests 1
source jsonparser.tcl
source jsonutilities.tcl

# Parse and modify JSON
set config [typed_json::json2dict $jsonString]
set newConfig [typed_json::setObjectByPath $config "server.host" {STRING "newhost"}]

# Use JSON text directly
set result [typed_json::setJsonObjectByPath $config "database.settings" {"timeout": 30}]

# Array manipulation
set updated [typed_json::insertIntoArrayAtPath $data "users" 0 {STRING "NewUser"}]
```

## API Reference

### Main Function
```tcl
typed_json::json2dict jsonString ?options?
```

### Options
```
-convert yes|no         - Convert JSON escapes to Tcl strings (default: yes)
-strict yes|no          - Disable JSON5 comments, enforce RFC 7159 compliance (default: no)
-maxnesting integer     - Maximum nesting depth (default: 2000)
-root name              - Wrap result in root element (default: "")
-surrogate mode         - Handle Unicode surrogate pairs: attempt|error|ignore|replace
-debug yes|no           - Enable tokenizer debug output (default: no)
```

### Utility Functions
```tcl
typed_json::getValue typedData                    # Extract value from typed element
typed_json::getType typedData                     # Get type of element
typed_json::isType typedData type                 # Check if element matches type
typed_json::getPath data "key.subkey"             # Navigate using dot notation
typed_json::findKey data keyName                  # Find all occurrences of key
typed_json::findByType data "STRING"              # Find all values of specific type
typed_json::getAllKeys data                       # Get all key paths recursively
typed_json::asPlainTcl data                       # Convert to plain Tcl dict/list
typed_json::asJson data                           # Convert back to JSON format
typed_json::asXml data                            # Convert to XML format
```

## Type Representation

JSON values are represented as typed Tcl structures:

| JSON Type | Representation |
|-----------|----------------|
| `"hello"` | `{STRING hello}` |
| `123` | `{NUMBER 123}` |
| `123.45` | `{NUMBER 123.45}` |
| `true` | `TRUE` |
| `false` | `FALSE` |
| `null` | `NULL` |
| `{}` | `{OBJECT {...}}` |
| `[]` | `{ARRAY {...}}` |

## Usage Examples

### Basic Navigation
```tcl
set json {{"users": ["Alice", "Bob"], "count": 2}}
set data [typed_json::json2dict $json]

# Navigate to nested values
set users [typed_json::getValue [typed_json::getPath $data "users"]]
foreach user $users {
    puts [typed_json::getValue $user]
}
# Output: Alice
#         Bob
```

### Key Discovery
```tcl
set data [typed_json::json2dict {{"name": "Alice", "details": {"age": 30, "city": "NYC"}}}]

# Get all keys
set keys [typed_json::getAllKeys $data]
puts $keys
# Output: name details details.age details.city

# Find specific types
set strings [typed_json::findByType $data "STRING"] 
foreach str $strings {
    puts [typed_json::getValue $str]
}
# Output: Alice
#         NYC
```

### Duplicate Key Handling

**Dict-based version (jsonparser.tcl):**
```tcl
set result [typed_json::json2dict {{"a":"first", "a":"second"}}]
# Result: OBJECT {a {STRING second}}  # Last wins
```

**List-based version (jsonparser-list.tcl):**
```tcl
set result [typed_json::json2dict {{"a":"first", "a":"second"}}] 
# Result: OBJECT {a {STRING first} a {STRING second}}  # Both preserved
```

### Unicode and Escapes
```tcl
# Basic escapes
set result [typed_json::convertEscapes "Hello\nWorld\t\"test\""]
# Result: Hello[newline]World[tab]"test"

# Unicode (including emoji with surrogate pairs in Tcl 9.0+)
set result [typed_json::json2dict {{"emoji": "Smile\uD83D\uDE00face"}}]
```

## Design Philosophy

This parser is intended for simple JSON processing where a pure Tcl solution is desirable, or for educational use demonstrating the flask lexing framework. It provides convenient utility functions for common operations and does not claim to be anywhere near as efficient as tDOM.

For applications requiring high-performance JSON processing, complex document manipulation, or handling of very large JSON datasets, consider using a tDOM binary solution.

**Key behaviors:**
- Dict version: "Last wins" for duplicate keys (consistent with most JSON parsers)
- List version: Preserves all duplicate keys in order (tDOM compatible)
- Type information preserved for accurate round-trip conversion  
- Utility functions designed for simple dict-style access patterns

## Requirements

- Tcl 8.6+ (Tcl 9.0+ recommended for full Unicode support)
- No external dependencies

## JSON Specification Compliance

Implements RFC 7159 with these behaviors:
- Duplicate object keys: Dict version uses "last wins", List version preserves all
- Comments: Supported by default (JSON5-style), disable with `-strict yes`
- Unicode: Full support including surrogate pairs for non-BMP characters
- Numbers: Supports integers, floats, and scientific notation
- Strings: Handles all standard JSON escape sequences

## Acknowledgements

This typed JSON implementation draws inspiration from the design principles established in tDOM's JSON parser by Rolf Ade and the tDOM development team. tDOM's approach to preserving JSON type information during parsing has been influential in the Tcl community for solving the fundamental challenge of round-trip JSON conversion in Tcl's string-oriented environment.

We thank Rolf Ade for his continued maintenance and development of tDOM, and for pioneering type-preserving JSON parsing patterns that benefit the entire Tcl ecosystem.

**tDOM project:** http://tdom.org  
**tDOM repository:** http://core.tcl.tk/tdom

## License

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS.

## See Also

- [typed-json wiki manual](https://wiki.tcl-lang.org/page/typed%2Djson) - Complete documentation and examples
- [flask - A mini flex/lex procedure](https://wiki.tcl-lang.org/page/flask+a+mini%2Dflex%2Flex+proc) - The lexing framework used by this parser
- [tDOM](https://wiki.tcl-lang.org/page/tDOM) - High-performance XML/JSON processing with DOM interface
- [JSON](https://wiki.tcl-lang.org/page/JSON) - Other Tcl JSON parsing solutions
- 
