package ifneeded profiling 1.0 [list apply { { dir } {
    load   [file join $dir profiling.so] Profiling
	source [file join $dir profiling.tcl]
} } $dir]
