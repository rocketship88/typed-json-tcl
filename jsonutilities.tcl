# typed_json - JSON Parser with Type Preservation
# Copyright (c) 2025 et99
# 
# This software was developed with assistance from Claude AI (Anthropic).
# Per Anthropic Consumer Terms of Service, Section 4 (as of May 1, 2025),
# as read on September 20, 2025:
# https://www.anthropic.com/legal/consumer-terms
# "Subject to your compliance with our Terms, we assign to you all of our 
# right, title, and interest--if any--in Outputs."
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted.
# 
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

namespace eval typed_json {

proc validateTypedJson {typedStructure} {
    # Handle single-token types
    if {[llength $typedStructure] == 1} {
        if {$typedStructure in {TRUE FALSE NULL}} {
            return true
        } else {
            error "Invalid single token: '$typedStructure' - must be TRUE, FALSE, or NULL"
        }
    }
    
    # Handle two-element types
    if {[llength $typedStructure] == 2} {
        lassign $typedStructure type data
        
        if {$type ni {STRING NUMBER OBJECT ARRAY}} {
            error "Invalid two-element type '$type' - must be STRING, NUMBER, OBJECT, or ARRAY"
        }
        
        switch $type {
            "NUMBER" {
                if {![string is double -strict $data]} {
                    error "Invalid NUMBER value '$data' - must be valid numeric"
                }
            }
            "OBJECT" {
                if {[catch {dict size $data}]} {
                    set dataStr [string range $data 0 19]
                    if {[string length $data] > 20} {
                        append dataStr "..."
                    }
                    error "Invalid OBJECT data '$dataStr' - must be valid dict"
                }
                dict for {key value} $data {
                    validateTypedJson $value
                }
            }
            "ARRAY" {
                foreach item $data {
                    validateTypedJson $item
                }
            }
        } ;# STRING - no validation needed, can be anything
        return true
    }
    
    error "Invalid structure: '$typedStructure' - must be single token or {TYPE data}"
}

# setObjectByPath function for modifying existing keys in typed JSON object structures
proc setObjectByPath {typedStructure path newTypedValue {guard "againstExtra"} {fullPath ""}} {
    variable delimiter
    # Guard against incorrect calling sequence
    if {$guard ne "againstExtra"} {
        error "Incorrect setObjectByPath calling sequence - too many arguments provided"
    }
    
    # Validate the new typed value before proceeding (recursive validation)
    validateTypedJson $newTypedValue
    
    # Set fullPath to path if not provided (initial call)
    if {$fullPath eq ""} {
        set fullPath $path
    }
    
    set pathParts [split $path $delimiter]
    
    # Handle root level assignment
    if {[llength $pathParts] == 1} {
        lassign $typedStructure rootType rootData
        if {$rootType eq "ARRAY"} {
            error "setObjectByPath cannot operate on arrays at path '$fullPath'. Use array-specific functions for array operations."
        } elseif {$rootType ni {OBJECT ARRAY}} {
            error "Path '$fullPath' not found: cannot navigate beyond leaf value of type $rootType"
        }
        # Check if key exists before setting
        if {![dict exists $rootData [lindex $pathParts 0]]} {
            error "Path '$fullPath' not found: key '[lindex $pathParts 0]' does not exist"
        }
        
        # No-op optimization: check if value is already what we want
        set currentValue [dict get $rootData [lindex $pathParts 0]]
        if {$currentValue eq $newTypedValue} {
            return $typedStructure  ;# No change needed
        }
        
        dict set rootData [lindex $pathParts 0] $newTypedValue
        return [list "OBJECT" $rootData]
    }
    
    # Recursive path navigation
    lassign $typedStructure rootType rootData
    if {$rootType eq "ARRAY"} {
        error "Cannot navigate into arrays with dot notation. Path '$fullPath' encounters array at this level. Use array-specific functions."
    } elseif {$rootType ni {OBJECT ARRAY}} {
        error "Path '$fullPath' not found: cannot navigate beyond leaf value of type $rootType"
    }
    
    set firstKey [lindex $pathParts 0]
    set remainingPath [join [lrange $pathParts 1 end] $delimiter]
    
    if {![dict exists $rootData $firstKey]} {
        error "Path '$fullPath' not found: key '$firstKey' does not exist"
    }
    
    set currentValue [dict get $rootData $firstKey]
    set modifiedValue [setObjectByPath $currentValue $remainingPath $newTypedValue "againstExtra" $fullPath]
    
    # No-op optimization: check if recursive call changed anything
    if {$currentValue eq $modifiedValue} {
        return $typedStructure  ;# No change was made
    }
    
    dict set rootData $firstKey $modifiedValue
    
    return [list "OBJECT" $rootData]
}

# setJsonObjectByPath function for modifying existing keys with JSON text
proc setJsonObjectByPath {typedStructure path jsonText} {
    # Parse the JSON text into typed structure
    if {[catch {
        set typedValue [typed_json::json2dict $jsonText]
    } errorMsg]} {
        error "setJsonObjectByPath: $errorMsg"
    }
    
    # Use setObjectByPath with the parsed value
    if {[catch {
        set result [setObjectByPath $typedStructure $path $typedValue]
    } errorMsg]} {
        error "setJsonObjectByPath: $errorMsg"
    }
    return $result
}
proc validateTclIndex {index} {
    # Check if it's a valid Tcl list index format
    if {[string is integer -strict $index]} {
        return true  ;# Regular integer
    }
    if {$index eq "end"} {
        return true  ;# Simple end
    }
    if {[regexp {^end[+-]\d+$} $index]} {
        return true  ;# end+N or end-N
    }
    return false
}

# Insert a typed value at a specific index in an array
proc insertIntoArrayAtPath {typedStructure path index newTypedValue} {
    # Validate index format
    if {![validateTclIndex $index]} {
        error "insertIntoArrayAtPath: Invalid index '$index' - must be integer, 'end', 'end+N', or 'end-N'"
    }
    
    # Validate the new typed value
    validateTypedJson $newTypedValue
    
    # Get current array at path
    set currentArray [typed_json::getPath $typedStructure $path]
    lassign $currentArray type data
    
    if {$type ne "ARRAY"} {
        error "insertIntoArrayAtPath: Path '$path' is not an array (found $type)"
    }
    
    # Use Tcl's linsert directly - it handles all the index magic
    set newData [linsert $data $index $newTypedValue]
    
    # Set the modified array back
    return [setObjectByPath $typedStructure $path [list "ARRAY" $newData]]
}

# Insert raw JSON text at a specific index in an array (parses JSON first)
proc insertJsonIntoArrayAtPath {typedStructure path index jsonText} {
    # Validate index format
    if {![validateTclIndex $index]} {
        error "insertJsonIntoArrayAtPath: Invalid index '$index' - must be integer, 'end', 'end+N', or 'end-N'"
    }
    
    # Parse the JSON text into typed structure
    if {[catch {
        set typedValue [typed_json::json2dict $jsonText]
    } errorMsg]} {
        error "insertJsonIntoArrayAtPath: $errorMsg"
    }
    
    # Use insertIntoArrayAtPath with the parsed value
    if {[catch {
        set result [insertIntoArrayAtPath $typedStructure $path $index $typedValue]
    } errorMsg]} {
        error "insertJsonIntoArrayAtPath: $errorMsg"
    }
    return $result
}
} ;# end namespace
