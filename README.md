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

# Quick Start

Both `jsonparser.tcl` and `jsonparser-list.tcl` are organized as runnable Tcl scripts with built-in test suites. This facilitates trying out the code by the simplest method of simply sourcing the file once downloaded.

## File Organization

Each parser file is structured as follows:

```tcl
# Parser implementation - The complete JSON parsing functionality
namespace eval typed_json {
    # ... parser code ...
}

# Test suite - Wrapped in conditional block
if {![info exists no_tests]} {
    # ... test code ...
}
```

## Basic Usage - Run and Test

```tcl
# Test the dict-based version
tclsh jsonparser.tcl

# Test the list-based version
tclsh jsonparser-list.tcl
```

## Interactive Testing

```tcl
tclsh
% set no_tests 1    ;# (if you don't want to run the built in tests)
% source jsonparser.tcl    ;# or jsonparser-list.tcl
% set data [typed_json::json2dict {{"name": "Alice", "age": 30}}]
OBJECT {name {STRING Alice} age {NUMBER 30}}
% puts [typed_json::getValue [typed_json::getPath $data "name"]]
Alice
```

## Using as a Standard Tcl Package

For integration into the standard Tcl package ecosystem, you can convert either parser into a module or a traditional package:

### Module Installation (.tm file)

1. Rename the desired parser file to include version information:
   ```bash
   # For dict-based parser
   cp jsonparser.tcl typed_json-1.0.tm
   
   # For list-based parser  
   cp jsonparser-list.tcl typed_json_list-1.0.tm
   ```

2. Remove or comment out the test suite section at the bottom of the file

3. Place the `.tm` file in a directory on Tcl's module path:
   ```tcl
   # View system module paths for system-wide installation
   puts [::tcl::tm::path list]
   
   # Or add a user directory if no admin rights
   ::tcl::tm::path add /path/to/your/modules
   ```

### Traditional Package Installation

Create a `pkgIndex.tcl` file in the same directory as your chosen parser implementation:

```tcl
# For dict-based parser
# pkgIndex.tcl
package ifneeded typed_json 1.0 [list source [file join $dir jsonparser.tcl]]

# For list-based parser  
# pkgIndex.tcl
package ifneeded typed_json_list 1.0 [list source [file join $dir jsonparser-list.tcl]]
```

Place this directory in a system-wide package location, or if you lack admin rights, add the directory to Tcl's package path at runtime:

```tcl
# View system package paths for system-wide installation
puts $auto_path

# Or add a user directory if no admin rights
lappend auto_path /path/to/your/package/directory
```

### Usage

Once installed using either method above, the parser can be loaded and used with the standard `package require` command:

```tcl
package require typed_json
# or
package require typed_json_list

set data [typed_json::json2dict {{"name": "Alice", "age": 30}}]
```
## API Reference

### Main Function
```tcl
typed_json::json2dict jsonString ?options?
```

**Options:**
- `-convert yes|no` - Convert JSON escapes to Tcl strings (default: yes)
- `-strict yes|no` - Disable JSON5 comments, enforce RFC 7159 compliance (default: no)
- `-maxnesting integer` - Maximum nesting depth (default: 2000)
- `-root name` - Wrap result in root element (default: "")
- `-surrogate mode` - Handle Unicode surrogate pairs: attempt|error|ignore|replace
- `-debug yes|no` - Enable tokenizer debug output (default: no)

### Utility Functions
```tcl
typed_json::getValue typedData          # Extract value from typed element
typed_json::getType typedData           # Get type of element  
typed_json::isType typedData type       # Check if element matches type
typed_json::getPath data "key.subkey"   # Navigate using dot notation
typed_json::findKey data keyName        # Find all occurrences of key
typed_json::findByType data "STRING"    # Find all values of specific type
typed_json::getAllKeys data             # Get all key paths recursively
typed_json::asPlainTcl data             # Convert to plain Tcl dict/list
typed_json::asJson data                 # Convert back to JSON format
typed_json::asXml data                  # Convert to XML format
```

## Type System

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

## Examples

### Basic Parsing
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

### Working with Objects  
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

## License

Permission to use, copy, modify, and/or distribute this software for any purpose with or without fee is hereby granted.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS.

## See Also

- [typed-json wiki manual](https://wiki.tcl-lang.org/page/typed%2Djson) - Complete documentation and examples
- [flask - A mini flex/lex procedure](https://wiki.tcl-lang.org/page/flask+a+mini%2Dflex%2Flex+proc) - The lexing framework used by this parser
- [tDOM](https://wiki.tcl-lang.org/page/tDOM) - High-performance XML/JSON processing with DOM interface
- [JSON](https://wiki.tcl-lang.org/page/JSON) - Other Tcl JSON parsing solutions
