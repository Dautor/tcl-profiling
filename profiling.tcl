package require Tcl 8.6

namespace eval ::profiling {
	namespace export instrument clear instrumentNamespace instrumentAll clearAll

	variable traced {}

	variable excludedNamespaces {
		::profiling
		::ttk
		::tk
		::tcl
		::oo
	}

	proc isExcluded { ns } {
		variable excludedNamespaces
		return [expr { $ns in $excludedNamespaces }]
	}

	proc instrument { name { refresh 1 } } {
		variable traced

		if { [dict exists $traced $name] } {
			return
		}

		if { ![llength [info procs $name]] } {
			return
		}

		trace add execution $name enter [list ::profiling::enter $name]
		trace add execution $name leave [list ::profiling::leave $name]

		dict set traced $name 1

		if { $refresh } {
			uiRefresh
		}
	}

	proc clear { name { refresh 1 } } {
		variable traced

		if { ![dict exists $traced $name] } {
			return
		}

		trace remove execution $name enter [list ::profiling::enter $name]
		trace remove execution $name leave [list ::profiling::leave $name]

		dict unset traced $name

		if { $refresh } {
			uiRefresh
		}
	}

	proc getProcedures { ns { recursive 1 } } {
		variable excludedNamespaces

		if { [isExcluded $ns] } {
			return {}
		}

		set result {}

		foreach name [info procs ${ns}::*] {
			lappend result $name
		}

		if { $recursive } {
			foreach child [namespace children $ns] {
				lappend result {*}[getProcedures $child]
			}
		}

		return $result
	}

	proc instrumentAll {} {
		foreach procedure [getProcedures ::] {
			instrument $procedure 0
		}

		uiRefresh
	}

	proc clearAll {} {
		variable traced

		dict for { name unused } $traced {
			trace remove execution $name enter [list ::profiling::enter $name]
			trace remove execution $name leave [list ::profiling::leave $name]
		}

		set traced {}

		uiRefresh
	}

	if {[llength [info commands winfo]] > 0} {
		variable tree ""
		variable filter ""

		proc uiRefresh {} {
			variable tree
			variable filter
			variable traced

			if { ![winfo exists $tree] } {
				return
			}

			# Preserve selection and focused item
			set selectedNames {}
			foreach item [$tree selection] {
				set values [$tree item $item -values]
				lappend selectedNames [lindex $values 1]
			}

			set focusedName ""
			set focused [$tree focus]
			if { $focused ne "" && [$tree exists $focused] } {
				set focusedName [lindex [$tree item $focused -values] 1]
			}

			# Rebuild the list
			$tree delete [$tree children {}]

			if { $filter ne "" && [catch { regexp -- $filter ""}] } {
				return
			}

			foreach name [lsort -unique [getProcedures ::]] {
				if { $filter ne "" && ![regexp -- $filter $name] } {
					continue
				}

				set status [ expr { [dict exists $traced $name] ? "Enabled" : "Disabled" }]

				$tree insert {} end -id $name -values [list $status $name]
			}

			# Restore selection
			set restoredSelection {}

			foreach name $selectedNames {
				if { [$tree exists $name] } {
					lappend restoredSelection $name
				}
			}

			$tree selection set $restoredSelection

			if { $focusedName ne "" && [$tree exists $focusedName] } {
				$tree focus $focusedName
			}
		}

		proc uiSetSelected { enabled } {
			variable tree

			set items [$tree selection]

			# If nothing is selected, use all currently visible rows
			if { ![llength $items] } {
				set items [$tree children {}]
			}

			set names {}

			foreach item $items {
				set values [$tree item $item -values]
				lappend names [lindex $values 1]
			}

			foreach name $names {
				if { $enabled } {
					instrument $name 0
				} else {
					clear $name 0
				}
			}

			uiRefresh
		}

		proc uiToggleAt { y } {
			variable tree
			variable traced

			set item [$tree identify item 0 $y]

			if { $item eq "" } {
				return
			}

			set name [lindex [$tree item $item -values] 1]

			if { [dict exists $traced $name] } {
				clear $name
			} else {
				instrument $name
			}

			uiRefresh
		}

		proc ui {} {
			variable tree

			if { [winfo exists .profiling] } {
				raise .profiling
				return
			}

			toplevel .profiling
			wm title .profiling "Tcl Profiling"
			wm geometry .profiling 600x700

			set frame [ttk::frame .profiling.main -padding 8]
			pack $frame -fill both -expand 1

			ttk::frame $frame.filter
			ttk::label $frame.filter.label -text "Filter (regex):"
			ttk::entry $frame.filter.entry \
				-textvariable ::profiling::uiFilter \
				-width 20

			pack $frame.filter.label -side left
			pack $frame.filter.entry -side right

			grid $frame.filter -row 0 -column 0 \
				-columnspan 2 -sticky ew -pady { 0 8 }

			bind $frame.filter.entry <KeyRelease> ::profiling::uiRefresh

			set tree [ttk::treeview $frame.list \
						  -columns { status name } \
						  -show headings \
						  -selectmode extended]

			bind $tree <Escape> { %W selection remove [%W selection] }

			$tree heading status -text "Profiling"
			$tree heading name -text "Procedure"

			$tree column status -width 90 -anchor center -stretch 0
			$tree column name -width 450 -anchor w

			set scrollbar [ttk::scrollbar $frame.scroll \
							   -orient vertical \
							   -command [list $tree yview]]

			$tree configure -yscrollcommand [list $scrollbar set]

			grid $tree -row 1 -column 0 -sticky nsew
			grid $scrollbar -row 1 -column 1 -sticky ns

			grid rowconfigure $frame 1 -weight 1
			grid columnconfigure $frame 0 -weight 1

			bind $tree <Double-1> [list ::profiling::uiToggleAt %y]

			set buttons [ttk::frame $frame.buttons]
			grid $buttons -row 2 -column 0 -columnspan 2 -sticky ew -pady { 8 0 }

			ttk::button $buttons.enable -text "Enable selected" \
				-command [list ::profiling::uiSetSelected 1]

			ttk::button $buttons.disable -text "Disable selected" \
				-command [list ::profiling::uiSetSelected 0]

			ttk::button $buttons.refresh -text "Refresh" \
				-command ::profiling::uiRefresh

			ttk::button $buttons.save -text "Save" \
				-command ::profiling::save

			ttk::button $buttons.load -text "Load" \
				-command ::profiling::load

			pack \
				$buttons.enable \
				$buttons.disable \
				$buttons.refresh \
				$buttons.save \
				$buttons.load \
				-side left -padx 3

			uiRefresh
		}
	} else {
		proc uiRefresh {} {}
		proc uiSetSelected { enabled } {}
		proc uiToggleAt { y } {}
		proc ui {} {}
	}

	proc configFile {} {
		return [file join [pwd] .profiling_data]
	}

	proc save {} {
		variable traced

		set filename [configFile]
		set f [open $filename w]

		try {
			puts $f [join [dict keys $traced] "\n"]
		} finally {
			close $f
		}
	}

	proc load {} {
		set filename [configFile]

		if { ![file exists $filename] } {
			return
		}

		set f [open $filename r]

		try {
			set names [split [read $f] "\n"]
		} finally {
			close $f
		}

		clearAll

		foreach name $names {
			set name [string trim $name]

			if { $name eq "" } {
				continue
			}

			instrument $name 0
		}

		uiRefresh
	}

}

package provide profiling 1.0
