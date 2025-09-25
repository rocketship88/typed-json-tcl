#!/usr/bin/env tclsh
catch {console show}
set ___lg___ [list tcl_rcFileName tcl_version argv0 argv tcl_interactive tk_library tk_version auto_path errorCode tk_strictMotif errorInfo auto_index env tcl_patchLevel argc tk_patchLevel tcl_libPath tcl_library tcl_platform ___lg___]
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

# First, include the flask procedure (from the wiki)
proc flask {regextokens data {flush yes} {debug no} {indent 3}} {
    set rpos 0
    set result {}
    set resultline {}
    set eos 0
    set newtokens [list]
    
    foreach {key RE actionlist comment} $regextokens {
        if [regexp {\A(\(\?[bceimnpqstwx]+\))(.*)} $RE -> meta pattern] {
            lappend newtokens $key "$meta\\A$pattern" $actionlist $comment
        } else {
            lappend newtokens $key "\\A$RE" $actionlist $comment
        }
    }
    
    set lastend -1
    while true {
        set found false
        foreach {key RE actionlist comment} $newtokens {
            if { [string index $key 0] eq "/" } {
                continue
            }
            if {[regexp -indices -start $rpos $RE $data match cap1 cap2 cap3 cap4 cap5 cap6 cap7 cap8 cap9]} {
                lassign $match start end
                if { $debug } {
                    set v1 [string range $data $rpos [expr { $rpos+$end-$start }]]
                    set v2 [string range $data [expr { $rpos+$end-$start+1 }] $rpos+50]
                    set v1 [string map {\n \u2936 \t \u02eb { } \u2219} $v1]
                    set v2 [string map {\n \u2936 \t \u02eb { } \u2219} $v2]
                    if { $lastend != -1 && $rpos != $lastend + 1 } {
                        puts -nonewline [format "%s%-10s %-40s (%5d %4d) " [string repeat " " $indent] $key $RE [expr { 0- $rpos }] $end]
                    } else {
                        puts -nonewline [format "%s%-10s %-40s (%5d %4d) " [string repeat " " $indent] $key $RE $rpos $end]
                    }
                    puts -nonewline "\U250A$v1\U250A"
                    puts "$v2\U2502"
                    set lastend $end
                    update
                }
                set action [lindex $actionlist 0]
                if { $action eq "token" } {
                    lappend resultline [list $key {*}$match]
                } elseif {$action eq "eos+token"} {
                    lappend resultline [list $key {*}$match]
                    set eos 1
                } elseif { $action eq "eos" } {
                    set eos 1
                } elseif { $action eq "new+token" } {
                    lappend result $resultline
                    set resultline [list]
                    lappend resultline [list $key {*}$match]
                } elseif { $action eq "new" } {
                    lappend result $resultline
                    set resultline [list]
                }
                if { [llength $actionlist] > 1 } {
                    set callback [lindex $actionlist 1]
                    set $ [string range $data $start $end]
                    eval $callback
                }
                set rpos [expr {$end+1}]
                set found true
                break
            }
        }
        if {$found} {
            if {$eos} {
                lappend result $resultline
                set resultline {}
                set eos 0
            }
        } else {
            if { $resultline ne {} && $flush} {
                lappend result $resultline
            }
            break
        }
    }
    return $result
}

# =============================================================================
# tDOM-style JSON Parser with Value-Based Typing
# =============================================================================

namespace eval typed_json {
    # Namespace variables for options (avoids parameter passing)
    variable convert
    variable maxNesting
    variable surrogateMode
    variable valid_followers
    array set valid_followers {
        LBRACE    {STRING RBRACE}
        STRING    {COLON COMMA RBRACE RBRACKET {}}
        COLON     {STRING  INTEGER FLOAT SCIENTIFIC TRUE FALSE NULL LBRACE LBRACKET}
        COMMA     {STRING  INTEGER FLOAT SCIENTIFIC NULL TRUE FALSE LBRACE LBRACKET}
        LBRACKET  {STRING  INTEGER FLOAT SCIENTIFIC TRUE FALSE NULL LBRACE LBRACKET RBRACKET}
        INTEGER     {COMMA RBRACE RBRACKET {}}
        FLOAT       {COMMA RBRACE RBRACKET {}}
        SCIENTIFIC  {COMMA RBRACE RBRACKET {}}
        TRUE      {COMMA RBRACE RBRACKET {}}
        FALSE     {COMMA RBRACE RBRACKET {}}
        NULL      {COMMA RBRACE RBRACKET {}}
        RBRACE    {COMMA RBRACE RBRACKET {}}
        RBRACKET  {COMMA RBRACE RBRACKET {}}
        STARTUP  {STRING INTEGER FLOAT SCIENTIFIC NULL TRUE FALSE}
        SINGLETOKEN   {NULL TRUE FALSE}
    }    
    # Export public API functions
    namespace export json2dict getValue getType isType findKey getPath \
                     findByType getAllKeys asPlainTcl asXml asJson convertEscapes
    
    # Main procedure - parses JSON and returns tDOM-style typed structure
    proc json2dict {jsonString args} {
        variable convert
        variable maxNesting
        variable surrogateMode
        
        # Set defaults
        array set opts {-maxnesting 2000 -root "" -debug no -strict no -convert yes }
        
        # Validate options before applying them
        set validOptions {-maxnesting -root -debug -strict -convert -surrogate}
        
        # Check for even number of arguments (option-value pairs)
        if {[llength $args] % 2 != 0} {
            error "Options must be specified as -option value pairs. Missing value for option '[lindex $args end]'"
        }
        
        foreach {key value} $args {
            if {$key ni $validOptions} {
                error "Invalid option '$key'. Valid options are: [join $validOptions {, }]"
            }
        }
        
        # Now safely apply user options
        array set opts $args
        
        # Auto-detect surrogate mode based on Tcl version if not specified
        if {![info exists opts(-surrogate)] || $opts(-surrogate) eq ""} {
            if {[package vcompare [info patchlevel] 9.0] >= 0} {
                set opts(-surrogate) "attempt"
            } else {
                set opts(-surrogate) "error"
            }
        }
        
        # Validate maxnesting is a positive integer
        if {![string is integer -strict $opts(-maxnesting)] || $opts(-maxnesting) < 1} {
            error "Invalid -maxnesting value '$opts(-maxnesting)'. Must be a positive integer."
        }
        
        # Set namespace variables from options
        set convert $opts(-convert)
        #puts "DEBUG: convert= |$convert| "
        set maxNesting $opts(-maxnesting)
        set surrogateMode $opts(-surrogate)
        
        # Define flask rules for JSON parsing with more specific number detection
        # ORDER MATTERS: More specific patterns must come first!
        set rules {
            COMMENT_1   {//[^\n\r]*}               skip     "single-line comment"
            COMMENT_N   {/\*[^*]*\*+(?:[^/*][^*]*\*+)*/} skip     "multi-line comment"
            WS       {[ \t\n\r]+}              skip     "whitespace"
            STRING     {\"([^\"\\\x00-\x1F]|\\.)*\"} token    "quoted string\""
            LEADING_0  {0\d}  {skip {error "Invalid number with leading zero: '${$}'"}}  "invalid leading zero"            SCIENTIFIC {-?(?:0|[1-9]\d*)(?:\.\d+)?[eE][+-]?\d+} token "scientific notation"
            FLOAT    {-?(?:0|[1-9]\d*)\.\d+}    token    "floating point number"
            INTEGER  {-?(?:0|[1-9]\d*)}         token    "integer number"
            LBRACE   {\{}                       token    "left brace - object start"
            RBRACE   {\}}                       token    "right brace - object end" 
            LBRACKET {\[}                       token    "left bracket - array start"
            RBRACKET {\]}                       token    "right bracket - array end"
            COLON    {:}                        token    "colon - key/value separator"
            COMMA    {,}                        token    "comma - item separator"
            TRUE     {true}                     token    "boolean true"
            FALSE    {false}                    token    "boolean false" 
            NULL     {null}                     token    "null value"
            ERROR    {.{1,10}}                  {skip {error "JSON parse error at '${$}'"}} "catch-all error handler"
        }
        
        # Disable comments if -strict mode is enabled
        if {$opts(-strict)} {
            set rules [regsub -all "COMMENT_" $rules "/COMMENT_"]
        }
        
        # Parse with flask (flush=yes is important!)
        set tokens [flask $rules $jsonString yes $opts(-debug)]
        set tokenList [lindex $tokens 0]  ;# Get first section
        # After tokenization, before parsing
        if {[llength $tokenList] == 0} {
            error "Empty JSON input - no valid tokens found"
        }
        # Build tDOM-style typed structure
        set result [buildTypedStructure $tokenList $jsonString]
        
        # If -root specified, wrap result in a root element
        if {$opts(-root) ne ""} {
            return [list "OBJECT" [dict create $opts(-root) $result]]
        }
        
        return $result
    }
    
    # Convert JSON escape sequences to actual characters
    # Handles surrogate pairs for non-BMP Unicode characters
    proc convertEscapes {str {surrogateMode "attempt"}} {
    #puts "DEBUG: convertEscapes called with: '$str'"
         set i [string first "\\" $str]
        if {$i < 0} {return $str}
        
        # Initialize result with everything before first backslash
        set result [string range $str 0 [expr {$i - 1}]]
        set len [string length $str]
        
        while {$i < $len} {
            set c [string index $str $i]
            if {$c eq "\\"} {
                if {$i + 1 >= $len} {
                    error "Invalid escape sequence: string ends with backslash"
                }
                
                set next [string index $str [expr {$i+1}]]
                switch $next {
                    n { append result \n; incr i 2 }
                    t { append result \t; incr i 2 }
                    r { append result \r; incr i 2 }
                    b { append result \b; incr i 2 }
                    f { append result \f; incr i 2 }
                    "\"" { append result "\""; incr i 2 }
                    / { append result /; incr i 2 }
                    \\ { append result \\; incr i 2 }
                    u {
                        # Unicode escape - validate we have enough characters
                        if {$i + 5 >= $len} {
                            error "Invalid Unicode escape: not enough characters for \\uXXXX"
                        }
                        
                        set hex [string range $str [expr {$i+2}] [expr {$i+5}]]
                        
                        # Validate hex digits (this also catches empty string)
                        if {![string is xdigit -strict $hex] || [string length $hex] != 4} {
                            error "Invalid Unicode escape: \\u$hex must have exactly 4 hex digits"
                        }
                        
                        scan $hex %x code
                        
                        # Check if this is a high surrogate (0xD800-0xDBFF)
                        if {$code >= 0xD800 && $code <= 0xDBFF} {
                            # High surrogate - must be followed by low surrogate
                            # Peek ahead for \uXXXX
                            set peek [string range $str [expr {$i+6}] [expr {$i+7}]]
                            if {$peek ne "\\u"} {
                                error "Orphaned high surrogate \\u$hex - expected low surrogate to follow"
                            }
                            
                            # Get the low surrogate hex
                            set hex2 [string range $str [expr {$i+8}] [expr {$i+11}]]
                            
                            # Validate it's hex and in low surrogate range
                            if {![string is xdigit -strict $hex2] || [string length $hex2] != 4} {
                                error "Invalid Unicode escape after high surrogate: \\u$hex2"
                            }
                            
                            scan $hex2 %x code2
                            if {$code2 < 0xDC00 || $code2 > 0xDFFF} {
                                error "Invalid surrogate pair: \\u$hex\\u$hex2 - second value must be DC00-DFFF"
                            }
                            
                            # Combine surrogate pair into actual Unicode codepoint
                            set combined [expr {0x10000 + (($code & 0x3FF) << 10) + ($code2 & 0x3FF)}]
                            
                            # Handle based on surrogate mode
                            switch $surrogateMode {
                                error {
                                    error "Surrogate pairs not supported in Tcl [info patchlevel] - use Tcl 9.0 or later"
                                }
                                ignore {
                                    # Skip both surrogates, append nothing
                                    incr i 12
                                }
                                attempt {
                                    # Try to create the character (works in Tcl 9.0+)
                                    append result [format %c $combined]
                                    incr i 12
                                }
                                replace {
                                    # Replace with Unicode notation
                                    append result "\\U[format %06X $combined]"
                                    incr i 12
                                }
                                default {
                                    error "Invalid surrogate mode: $surrogateMode (use error, ignore, attempt, or replace)"
                                }
                            }
                        } elseif {$code >= 0xDC00 && $code <= 0xDFFF} {
                            # Low surrogate without preceding high surrogate
                            error "Orphaned low surrogate \\u$hex - must follow a high surrogate"
                        } else {
                            # Normal BMP character
                            append result [format %c $code]
                            incr i 6
                        }
                    }
                    default {
                        # Unknown escape - keep as-is
                        error "invalid escape \\$next"
                        append result \\$next
                        incr i 2
                    }
                }
            } else {
                append result $c
                incr i
            }
        }
        return $result
    }
    
    # Build tDOM-style structure: each value has format {TYPE value}
    proc buildTypedStructure {tokenList jsonString {currentDepth 0}} {
        variable maxNesting
        variable valid_followers
        variable convert
        variable surrogateMode
        
        set tokenCount [llength $tokenList]
        
        if {$tokenCount == 0} {
            error "Empty JSON input"
        } elseif {$tokenCount == 1} {
            # Process single scalar value
            set tokenType [lindex $tokenList 0 0]
            
            if {$tokenType ni $valid_followers(STARTUP)} {
                error "Invalid JSON: '$tokenType' cannot be a standalone value"
            }
            
            if {$tokenType in $valid_followers(SINGLETOKEN)} {
                # Return just the token type (TRUE, FALSE, NULL)
                return $tokenType
            } else {
                # Extract value and wrap with type (STRING, NUMBER, etc.)
                set start [lindex $tokenList 0 1]
                set end [lindex $tokenList 0 2]
                set value [string range $jsonString $start $end]
                
                # Apply processing based on type
                switch $tokenType {
                    "STRING" {
                        # Remove quotes and convert escapes
                        set cleanValue [string range $value 1 end-1]
                        if {$convert} {
                            set cleanValue [convertEscapes $cleanValue $surrogateMode]
                        }
                        return [list "STRING" $cleanValue]
                    }
                    "INTEGER" - "FLOAT" - "SCIENTIFIC" {
                        return [list "NUMBER" $value]
                    }
                    default {
                        return [list $tokenType $value]
                    }
                }
            }
        } else {
            # Multiple tokens - must be container or invalid
            set firstType [lindex $tokenList 0 0]
            
            # Validate that second token is a valid follower of first token
            if {[llength $tokenList] > 1} {
                set secondType [lindex $tokenList 1 0]
                if {$secondType ni $valid_followers($firstType)} {
                    error "Invalid JSON: $firstType cannot be followed by '$secondType'"
                }
            }
            
            if {$firstType eq "LBRACKET"} {
                # Handle array
                set arrEnd [findMatchingDelimiter $tokenList 0 "bracket" $jsonString]
                
                # Check for trailing tokens after array
                if {$arrEnd + 1 < [llength $tokenList]} {
                    set unexpectedToken [lindex $tokenList [expr {$arrEnd + 1}]]
                    lassign $unexpectedToken tokenType tokenStart tokenEnd
                    set tokenText [string range $jsonString $tokenStart $tokenEnd]
                    error "Unexpected tokens after array: $tokenType \"$tokenText\""
                }
                
                set arrayTokens [lrange $tokenList 1 [expr {$arrEnd-1}]]
                return [list "ARRAY" [parseTypedArray $arrayTokens $jsonString [expr {$currentDepth + 1}]]]
            } elseif {$firstType eq "LBRACE"} {
                # Handle object
                set objEnd [findMatchingDelimiter $tokenList 0 "brace" $jsonString]
                
                # Check for trailing tokens after object
                if {$objEnd + 1 < [llength $tokenList]} {
                    set unexpectedToken [lindex $tokenList [expr {$objEnd + 1}]]
                    lassign $unexpectedToken tokenType tokenStart tokenEnd
                    set tokenText [string range $jsonString $tokenStart $tokenEnd]
                    error "Unexpected tokens after object: $tokenType \"$tokenText\""
                }
                
                set objectTokens [lrange $tokenList 1 [expr {$objEnd-1}]]
                return [list "OBJECT" [parseTypedObject $objectTokens $jsonString [expr {$currentDepth + 1}]]]
            } else {
                # Invalid - multiple tokens not in container
                error "Invalid JSON: multiple values without container"
            }
        }
    }
    

    # Parse object contents into tDOM-style format
    proc parseTypedObject {tokenList jsonString {currentDepth 0}} {
        variable convert
        variable maxNesting
        variable surrogateMode
        variable valid_followers 
               
        # Check nesting depth
        if {$currentDepth > $maxNesting} {
            error "JSON nesting too deep (max: $maxNesting, current: $currentDepth)"
        }
        
        set result {}
        set i 0
        set currentKey ""
        set expectingKey true
        
        while {$i < [llength $tokenList]} {
            lassign [lindex $tokenList $i] type start end
            set value [string range $jsonString $start $end]
            
            # Grammar validation check  
            set nextType [lindex [lindex $tokenList [expr {$i + 1}]] 0]
            
            if {$nextType ni $valid_followers($type)} {
                error "Invalid JSON: $type cannot be followed by '$nextType'"
            }

            switch $type {
                "STRING" {
                    set cleanValue [string range $value 1 end-1]  ;# Remove quotes
                    
                    # Apply escape conversion if enabled
                    if {$convert} {
                        set cleanValue [convertEscapes $cleanValue $surrogateMode]
                    }
                    
                    if {$expectingKey} {
                        set currentKey $cleanValue
                        # Validate that next token is COLON
                        if {$nextType ne "COLON"} {
                            error "Expected ':' after object key '$currentKey', found '$nextType'"

                        }
                        set expectingKey false
                    } else {
                        # This is a value
                        dict set result $currentKey [list "STRING" $cleanValue]
                        set expectingKey true
                    }
                }
               "INTEGER" {
                    dict set result $currentKey [list "NUMBER" $value]
                    set expectingKey true
                }
                "FLOAT" - "SCIENTIFIC" {
                    dict set result $currentKey [list "NUMBER" $value]
                    set expectingKey true
                }
                "TRUE" {
                    dict set result $currentKey "TRUE"
                    set expectingKey true
                }
                "FALSE" {
                    dict set result $currentKey "FALSE" 
                    set expectingKey true
                }
                "NULL" {
                    dict set result $currentKey "NULL"
                    set expectingKey true
                }
                "LBRACE" {
                    # Nested object
                    set objEnd [findMatchingDelimiter  $tokenList $i "brace" $jsonString]
                    set nestedTokens [lrange $tokenList [expr {$i+1}] [expr {$objEnd-1}]]
                    set nestedResult [parseTypedObject $nestedTokens $jsonString [expr {$currentDepth + 1}]]
                    dict set result $currentKey [list "OBJECT" $nestedResult]
                    set i $objEnd
                    set expectingKey true
                }
                "LBRACKET" {
                    # Array
                    set arrEnd [findMatchingDelimiter  $tokenList $i "bracket" $jsonString]
                    set arrayTokens [lrange $tokenList [expr {$i+1}] [expr {$arrEnd-1}]]
                    set arrayResult [parseTypedArray $arrayTokens $jsonString [expr {$currentDepth + 1}]]
                    dict set result $currentKey [list "ARRAY" $arrayResult]
                    set i $arrEnd
                    set expectingKey true
                }
                
                
                "RBRACE" {
                    error "starting with a right brace"
                }
                "RBRACKET" {
                    error "starting with a right bracket"
                }
                
                
                "COLON" {
                    # Key-value separator, continue
                }
                "COMMA" {
                    # Item separator, expect next key
                    set expectingKey true
                }
            }
            incr i
        }
        
        return $result
    }
    
    # Parse array contents into tDOM-style format  
    proc parseTypedArray {tokenList jsonString {currentDepth 0}} {
        variable convert
        variable maxNesting
        variable surrogateMode
        variable valid_followers 
               
        # Check nesting depth
        if {$currentDepth > $maxNesting} {
            error "JSON nesting too deep (max: $maxNesting, current: $currentDepth)"
        }
        
        set result {}
        set i 0
        
        while {$i < [llength $tokenList]} {
            lassign [lindex $tokenList $i] type start end
            set value [string range $jsonString $start $end]
            
            # Grammar validation check  
            set nextType [lindex [lindex $tokenList [expr {$i + 1}]] 0]
            
            if {$nextType ni $valid_followers($type)} {
                error "Invalid JSON: $type cannot be followed by '$nextType'"
            }
            switch $type {
                "STRING" {
                    set cleanValue [string range $value 1 end-1]  ;# Remove quotes
                    
                    # Apply escape conversion if enabled
                    if {$convert} {
                        set cleanValue [convertEscapes $cleanValue $surrogateMode]
                    }
                    
                    lappend result [list "STRING" $cleanValue]
                }
                "INTEGER" - "FLOAT" - "SCIENTIFIC" {
                    lappend result [list "NUMBER" $value]
                }
                "TRUE" {
                    lappend result "TRUE"
                }
                "FALSE" {
                    lappend result "FALSE"
                }
                "NULL" {
                    lappend result "NULL"
                }
                "LBRACE" {
                    # Nested object in array
                    set objEnd [findMatchingDelimiter  $tokenList $i "brace" $jsonString]
                    set nestedTokens [lrange $tokenList [expr {$i+1}] [expr {$objEnd-1}]]
                    set nestedResult [parseTypedObject $nestedTokens $jsonString [expr {$currentDepth + 1}]]
                    lappend result [list "OBJECT" $nestedResult]
                    set i $objEnd
                }
                "LBRACKET" {
                    # Nested array
                    set arrEnd [findMatchingDelimiter  $tokenList $i "bracket" $jsonString]
                    set nestedTokens [lrange $tokenList [expr {$i+1}] [expr {$arrEnd-1}]]
                    set nestedResult [parseTypedArray $nestedTokens $jsonString [expr {$currentDepth + 1}]]
                    lappend result [list "ARRAY" $nestedResult]
                    set i $arrEnd
                }
                "RBRACE" {
                    error "starting with a right brace"
                }
                "RBRACKET" {
                    error "starting with a right bracket"
                }
                
                "COMMA" {
                    # Item separator, continue
                }
                "COLON" {
                    error "Invalid array separator : use a comma"
                }
            }
            incr i
        }
        
        return $result
    }
    

    proc findMatchingDelimiter {tokenList start delimiterType jsonString} {
        if {$delimiterType eq "brace"} {
            set openToken "LBRACE"
            set closeToken "RBRACE"
            set openChar "\{"
            set closeChar "\}"
        } else {
            set openToken "LBRACKET"
            set closeToken "RBRACKET"
            set openChar "\["
            set closeChar "\]"
        }
        
        set depth 0
        for {set i $start} {$i < [llength $tokenList]} {incr i} {
            set type [lindex [lindex $tokenList $i] 0]
            if {$type eq $openToken} {
                incr depth
            } elseif {$type eq $closeToken} {
                incr depth -1
                if {$depth == 0} {
                    return $i
                }
            }
        }
        
        # Error handling - no matching delimiter found
        set nextToken [lindex $tokenList [expr {$start + 1}]]
        if {$nextToken ne ""} {
            lassign $nextToken type startPos endPos
            set tokenText [string range $jsonString $startPos $endPos]
            error "no matching '$closeChar' for '$openChar' at $type `$tokenText`"
        } else {
            error "no matching '$closeChar' for '$openChar' at end of input"
        }
    }
    # Utility functions for working with tDOM-style typed data
    proc getValue {typedData} {
        if {[llength $typedData] == 2} {
            return [lindex $typedData 1]
        } else {
            return $typedData  ;# Special values like TRUE, FALSE, NULL
        }
    }
    
    proc getType {typedData} {
        if {[llength $typedData] == 2} {
            return [lindex $typedData 0]
        } else {
            return $typedData  ;# Special values ARE their type
        }
    }
    
    proc isType {typedData expectedType} {
        return [expr {[getType $typedData] eq $expectedType}]
    }
    
    # Find all occurrences of a key name (recursively)
    proc findKey {typedStructure keyName} {
        set results {}
        lassign $typedStructure rootType rootData
        
        if {$rootType eq "OBJECT"} {
            dict for {key typedValue} $rootData {
                if {$key eq $keyName} {
                    lappend results [list "found" $key $typedValue]
                }
                # Recurse into nested structures
                if {[getType $typedValue] eq "OBJECT"} {
                    set nestedResults [findKey $typedValue $keyName]
                    set results [concat $results $nestedResults]
                } elseif {[getType $typedValue] eq "ARRAY"} {
                    foreach item [getValue $typedValue] {
                        if {[getType $item] eq "OBJECT"} {
                            set nestedResults [findKey $item $keyName]
                            set results [concat $results $nestedResults]
                        }
                    }
                }
            }
        }
        return $results
    }
    
    # Navigate to a path like "user.address.street" 
    proc getPath {typedStructure path} {
        set pathParts [split $path "."]
        set current $typedStructure
        
        foreach part $pathParts {
            lassign $current currentType currentData
            
            if {$currentType eq "OBJECT"} {
                if {[dict exists $currentData $part]} {
                    set current [dict get $currentData $part]
                } else {
                    error "Path not found: key '$part' does not exist"
                }
            } else {
                error "Path not found: trying to access key '$part' in non-object (type: $currentType)"
            }
        }
        
        return $current
    }
    
    # Find all values of a specific type (STRING, NUMBER, etc.)
    proc findByType {typedStructure targetType} {
        set results {}
        lassign $typedStructure rootType rootData
        
        if {$rootType eq $targetType} {
            lappend results $typedStructure
        } elseif {$rootType eq "OBJECT"} {
            dict for {key typedValue} $rootData {
                if {[getType $typedValue] eq $targetType} {
                    lappend results $typedValue
                }
                # Recurse into nested structures
                if {[getType $typedValue] eq "OBJECT" || [getType $typedValue] eq "ARRAY"} {
                    set nestedResults [findByType $typedValue $targetType]
                    set results [concat $results $nestedResults]
                }
            }
        } elseif {$rootType eq "ARRAY"} {
            foreach item $rootData {
                if {[getType $item] eq $targetType} {
                    lappend results $item
                }
                # Recurse into nested structures
                if {[getType $item] eq "OBJECT" || [getType $item] eq "ARRAY"} {
                    set nestedResults [findByType $item $targetType]
                    set results [concat $results $nestedResults]
                }
            }
        }
        
        return $results
    }
    
    # Get all keys from the structure (recursively)
    proc getAllKeys {typedStructure {prefix ""}} {
        set keys {}
        lassign $typedStructure rootType rootData
        
        if {$rootType eq "OBJECT"} {
            dict for {key typedValue} $rootData {
                set fullKey [expr {$prefix eq "" ? $key : "$prefix.$key"}]
                lappend keys $fullKey
                
                # Recurse into nested objects
                if {[getType $typedValue] eq "OBJECT"} {
                    set nestedKeys [getAllKeys $typedValue $fullKey]
                    set keys [concat $keys $nestedKeys]
                } elseif {[getType $typedValue] eq "ARRAY"} {
                    # Look for objects within arrays
                    set arrayData [getValue $typedValue]
                    set index 0
                    foreach item $arrayData {
                        if {[getType $item] eq "OBJECT"} {
                            set arrayItemPath "$fullKey\[$index\]"
                            set nestedKeys [getAllKeys $item $arrayItemPath]
                            set keys [concat $keys $nestedKeys]
                        }
                        incr index
                    }
                }
            }
        }
        
        return $keys
    }
    
    # Convert typed structure back to plain Tcl dict/list (lose type info)
    proc asPlainTcl {typedStructure} {
        lassign $typedStructure rootType rootData
        
        switch $rootType {
            "STRING" - "NUMBER" {
                return $rootData
            }
            "TRUE" {
                return true
            }
            "FALSE" {
                return false  
            }
            "NULL" {
                return ""
            }
            "OBJECT" {
                set result {}
                dict for {key typedValue} $rootData {
                    dict set result $key [asPlainTcl $typedValue]
                }
                return $result
            }
            "ARRAY" {
                set result {}
                foreach item $rootData {
                    lappend result [asPlainTcl $item]
                }
                return $result
            }
        }
    }
    
    # Convert typed structure to XML format
    proc asXml {typedStructure {indent ""} {ascii no}} {
        lassign $typedStructure rootType rootData
        
        switch $rootType {
            "STRING" {
                # Escape XML special characters
                set escaped [string map {"&" "&amp;" "<" "&lt;" ">" "&gt;" "\"" "&quot;" "'" "&apos;"} $rootData]
                # Optionally convert Unicode and special chars to character references
                if {$ascii} {
                    # First convert newlines and other control characters
                    set escaped [string map {"\n" "&#xA;" "\r" "&#xD;" "\t" "&#x9;"} $escaped]
                    
                    # Then convert remaining Unicode (>127)
                    set result ""
                    foreach char [split $escaped ""] {
                        scan $char %c code
                        if {$code > 127} {
                            append result "&#x[format %X $code];"
                        } else {
                            append result $char
                        }
                    }
                    set escaped $result
                }
                
                return "$indent<string>$escaped</string>"
            }
            "NUMBER" {
                return "$indent<number>$rootData</number>"
            }
            "TRUE" {
                return "$indent<boolean>true</boolean>"
            }
            "FALSE" {
                return "$indent<boolean>false</boolean>"
            }
            "NULL" {
                return "$indent<null/>"
            }
            "OBJECT" {
                set xml "$indent<object>\n"
                dict for {key typedValue} $rootData {
                    append xml "$indent  <item key=\"$key\">\n"
                    append xml [asXml $typedValue "$indent    " $ascii]
                    append xml "\n$indent  </item>\n"
                }
                append xml "$indent</object>"
                return $xml
            }
            "ARRAY" {
                set xml "$indent<array>\n"
                foreach item $rootData {
                    append xml [asXml $item "$indent  " $ascii]
                    append xml "\n"
                }
                append xml "$indent</array>"
                return $xml
            }
        }
    }    

# Convert typed structure back to JSON format
    proc asJson {typedStructure {indent ""} {ascii no}} {
        lassign $typedStructure rootType rootData
        
        switch $rootType {
            "STRING" {
                # Escape JSON special characters
                set escaped [string map {
                    \\ \\\\
                    \" \\\"
                    \n \\n
                    \r \\r
                    \t \\t
                    \b \\b
                    \f \\f
                } $rootData]
                
                # Optionally convert Unicode to \uXXXX format
                if {$ascii} {
                    set result ""
                    foreach char [split $escaped ""] {
                        scan $char %c code
                        if {$code > 0xFFFF} {
                            # Need to encode as surrogate pair
                            set adjusted [expr {$code - 0x10000}]
                            set high [expr {0xD800 + (($adjusted >> 10) & 0x3FF)}]
                            set low [expr {0xDC00 + ($adjusted & 0x3FF)}]
                            append result [format \\u%04X\\u%04X $high $low]
                        } elseif {$code > 127 || $code < 32} {
                            append result [format \\u%04X $code]
                        } else {
                            append result $char
                        }
                    }
                    set escaped $result
                }
                
                return "$indent\"$escaped\""
            }
            "NUMBER" {
                return "$indent$rootData"
            }
            "TRUE" {
                return "${indent}true"
            }
            "FALSE" {
                return "${indent}false"
            }
            "NULL" {
                return "${indent}null"
            }
            "OBJECT" {
                set json "$indent\{\n"
                set first true
                dict for {key typedValue} $rootData {
                    if {!$first} {append json ",\n"} else {set first false}
                    append json "$indent  \"$key\": "
                    append json [string trimleft [asJson $typedValue "$indent  " $ascii] " "]
                }
                append json "\n$indent\}"
                return $json
            }
            "ARRAY" {
                set json "$indent\[\n"
                set first true
                foreach item $rootData {
                    if {!$first} {append json ",\n"} else {set first false}
                    append json [asJson $item "$indent  " $ascii]
                }
                append json "\n$indent\]"
                return $json
            }
        }
    }
}

if {![info exist no_tests]} {
# =============================================================================
# Test with various JSON types
# =============================================================================

#Test JSON that shows all type distinctions
set testJson {{
        "stringproperty": "abc",
        "stringnumber": "123",
        "integernumber": 123,
        "floatnumber": 123.45,
        "scientificnumber": 1.23e-4,
        "objectproperty": {"one": 1, "two": "2"},
        "array": ["foo", 2, "2", null, true, false, {"nested": "object"}, [1,"nested","array"]],
        "null": null,
        "true": true,
        "false": false
    }}

puts "=== tDOM-style JSON Parser with Value-Based Typing ==="
puts ""

set result [typed_json::json2dict $testJson]
puts "1. Full typed structure:"
puts $result
puts ""

#Extract the OBJECT data from the result
lassign $result rootType rootData
if {$rootType eq "OBJECT"} {
    puts "2. Demonstrating type distinctions:"
    
    # String vs Number
    set stringnum [dict get $rootData "stringnumber"]
    set intnum [dict get $rootData "integernumber"]
    puts "   \"123\" (string): [typed_json::getType $stringnum] = [typed_json::getValue $stringnum]"
    puts "   123 (number):    [typed_json::getType $intnum] = [typed_json::getValue $intnum]"
    
    # Different number types
    set floatnum [dict get $rootData "floatnumber"]
    set scinotnum [dict get $rootData "scientificnumber"]
    puts "   123.45:     [typed_json::getType $floatnum] = [typed_json::getValue $floatnum]"
    puts "   1.23e-4:    [typed_json::getType $scinotnum] = [typed_json::getValue $scinotnum]"
    
    # Boolean and null
    set nullval [dict get $rootData "null"]
    set trueval [dict get $rootData "true"]
    puts "   null:       [typed_json::getType $nullval]"
    puts "   true:       [typed_json::getType $trueval]"
    
    puts ""
    puts "3. Working with arrays (no keys needed!):"
    set arrayData [dict get $rootData "array"]
    lassign $arrayData arrayType arrayContents
    puts "   Array type: $arrayType"
    puts "   Array contents:"
    
    set i 0
    foreach item $arrayContents {
        puts "     \[$i\]: [typed_json::getType $item] = [typed_json::getValue $item]"
        incr i
    }
}

puts ""
puts "4. Root-level array example:"
set rootArrayJson {["apple", 42, "42", true, null, {"key": "value"}]}
set arrayResult [typed_json::json2dict $rootArrayJson]
lassign $arrayResult rootType rootContents
puts "   Root type: $rootType"
puts "   Contents:"
set i 0
foreach item $rootContents {
    puts "     \[$i\]: [typed_json::getType $item] = [typed_json::getValue $item]"
    incr i
}

puts ""
puts "5. Testing with options:"
set debugResult [typed_json::json2dict {{"key": "value"}} -debug no -root "wrapper"]
puts "   With -debug no -root \"wrapper\":"
puts "   Result: $debugResult"

set testJson2 {{
        "stringproperty": "abc",
        "objectproperty": {"one": 1, "two": "two"},
        "array": ["foo", -2.23, null, true, false, {"one": 1, "two": "two"}, [2,16,24]],
        "number": 2022,
        "null": null,
        "true": true,
        "false":  false
    }}

set result2 "error"
if [catch {
    set result2 [typed_json::json2dict $testJson2 -debug no]
} err_code] {
    puts stderr $err_code
}
puts "\n6. Full typed structure for usenet example:"
puts $result2
puts ""

puts "7. Utility function examples:"
set sampleData ""
set surrogateMode [expr {[package vcompare [info patchlevel] 9.0] >= 0 ? "" : "attempt"}]
if [catch {
    set sampleData [typed_json::json2dict {{
            "user": {
                "name": "Alice \uD83D\uDE00\uD83D\uDE0E  \nwith newline\u2022 <- unicode \" imbedded quote\\  ",
                "age": 30,
                "contacts": {
                    "email": "alice@example.com",
                    "phone": "555-1234"
                }
            },
            "products": [
            {"name": "Widget", "price": 19.99},
            {"name": "Gadget", "price": 29.99}
        ],
            "settings": {
                "debug": true,
                "timeout": 5000
            }
        }} -surrogate $surrogateMode]
} err_code] {
    puts "Error: $err_code "
}

if [catch {
    # Find all occurrences of "name" key
    puts "   Finding all 'name' keys:"
    set nameResults [typed_json::findKey $sampleData "name"]
    foreach result $nameResults {
        lassign $result status key typedValue
        puts "     Found: $key = [typed_json::getValue $typedValue] (type: [typed_json::getType $typedValue])"
    }
    
#   Navigate to specific path
    puts "   Path navigation:"
    set emailValue [typed_json::getPath $sampleData "user.contacts.email"]
    puts "     user.contacts.email = [typed_json::getValue $emailValue]"
    
#   Find all strings
    puts "   All STRING values:"
    set allStrings [typed_json::findByType $sampleData "STRING"]
    foreach str $allStrings {
        puts "     \"[typed_json::getValue $str]\""
    }
    
#   Get all keys
    puts "   All keys in structure:"
    set allKeys [typed_json::getAllKeys $sampleData]
    foreach key $allKeys {
        puts "     $key"
    }
    
#   Convert back to plain Tcl
    puts "\n-----    Convert to plain Tcl (type info lost):"
    set plainTcl [typed_json::asPlainTcl $sampleData]
    puts "     $plainTcl"
    
#   Convert to XML
    puts "\n-----   Convert to XML (ASCII mode):"
    set xmlOutput [typed_json::asXml $sampleData "" yes]
    puts $xmlOutput
    
#   Convert back to JSON
    puts "\n-----   Convert back to JSON (ASCII mode):"
    set jsonOutput [typed_json::asJson $sampleData "" yes]
    puts $jsonOutput
    
    
    puts "\n-----   Round-trip test: JSON -> typed -> JSON -> typed"
    set sampleData2 [typed_json::json2dict $jsonOutput]
    if {$sampleData2 != $sampleData} {
        puts "FAILED: Structures don't match!"
        puts "$sampleData2\n != \n$sampleData"
    } else {
        puts "PASSED: Round-trip successful - structures match exactly"
    }
} err_code] {
    puts "Error: $err_code"
}


#Just for this test file
namespace import typed_json::convertEscapes

#Now you can call it directly
#set output [convertEscapes $input]

#Test cases
if [catch {
    
    puts "\n\nTesting Unicode escape conversion with surrogate pairs\n"
    
#   Test 1: Basic escapes
    puts "Test 1: Basic escapes"
    set input "Hello\\nWorld\\t\\\""
    set output [convertEscapes $input]
    puts "Input:  $input"
    puts "Output: $output"
    puts ""
    
#   Test 2: BMP Unicode (simple \uXXXX)
    puts "Test 2: BMP Unicode"
    set input "Bullet\\u2022"
    set output [convertEscapes $input]
    puts "Input:  $input"
    puts "Output: $output"
    puts ""
    
#   Test 3: Emoji via surrogate pair
    puts "Test 3: Emoji (surrogate pair)"
    set input "Grinning\\uD83D\\uDE00face"
    set output [convertEscapes $input]
    puts "Input:  $input"
    puts "Output: $output"
    puts ""
    
#   Test 4: Multiple emojis
    puts "Test 4: Multiple emojis"
    set input "\\uD83D\\uDE00\\uD83D\\uDE0E"
    set output [convertEscapes $input]
    puts "Input:  $input"
    puts "Output: $output"
    puts ""
    
#   Test 5: Mixed content
    puts "Test 5: Mixed BMP and surrogate pairs"
    set input "Star\\u2B50and\\uD83C\\uDF1Fsparkle"
    set output [convertEscapes $input]
    puts "Input:  $input"
    puts "Output: $output"
    puts ""
    
#   Error tests
    puts "Error tests:"
    
#   Test 6: Orphaned high surrogate
    puts "\nTest 6: Orphaned high surrogate (should error)"
    if {[catch {convertEscapes "\\uD83Dno-low"} err]} {
        puts "Error (expected): $err"
    }
    
#   Test 7: Orphaned low surrogate
    puts "\nTest 7: Orphaned low surrogate (should error)"
    if {[catch {convertEscapes "\\uDE00orphaned"} err]} {
        puts "Error (expected): $err"
    }
    
#   Test 8: Invalid surrogate pair
    puts "\nTest 8: Invalid surrogate pair (should error)"
    if {[catch {convertEscapes "\\uD83D\\u0041"} err]} {
        puts "Error (expected): $err"
    }
    
    puts "\nAll tests complete!"
    
} err_code details] {
    puts "error: $err_code\n\n $details"
}
#set ::___lg___ ""
#Extra lines for easy copy/paste
proc lg {{pat **} {delimeter |} {max 80}} {          # list globals
    set a [lsort -dictionary [info global ${pat}*]]
    foreach gvar $a {
        if { $gvar in $::___lg___  && $pat eq "**"} {
            continue
        }
        if {[array exists ::$gvar]} { ;# it is an array get some indices
            set val "() [lsort -dictionary [array names ::$gvar]]"
        } elseif { [info exists ::${gvar}] } {
            set val ${delimeter}[set ::${gvar}]$delimeter
            regsub -all {\n} $val [apply {code {eval set str "\\u[string map "U+ {}" $code]"}} 2936] val ;# or 21B2
        } else {
            continue ;# skip if we cant get the value
        }
        catch {
            puts [format "--- %-20s = %s" $gvar [string range $val 0 $max]]
        }
    }
}
}
