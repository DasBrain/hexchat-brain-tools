package require dasbrain::channels
package require dasbrain::chanopt
package require dns
package require ip

package provide dasbrain::dronebl 1.0

namespace eval ::dasbrain::dronebl {
	::dasbrain::channels::on-event join ::dasbrain::dronebl::JOIN
	::dasbrain::chanopt::register dronebl flag 0
	
	variable dronebl-classes {
		1 	{Testing class.}
		2 	{Sample data used for heruistical analysis}
		3 	{IRC spam drone (litmus/sdbot/fyle)}
		5 	{Bottler (experimental)}
		6 	{Unknown worm or spambot}
		7 	{DDoS drone}
		8 	{Open SOCKS proxy}
		9 	{Open HTTP proxy}
		10 	{Proxychain}
		11 	{Web Page Proxy}
		12 	{Open DNS Resolver}
		13 	{Automated dictionary attacks}
		14 	{Open WINGATE proxy}
		15 	{Compromised router / gateway}
		16 	{Autorooting worms}
		17 	{Automatically determined botnet IPs (experimental)}
		18 	{Possibly compromised DNS/MX type hostname detected on IRC}
		19 	{Abused VPN Service}
		255 	{Uncategorized threat class}
	}
}

# TODO: add caching

proc ::dasbrain::dronebl::JOIN {chan userrec} {
	if {![dict exists $userrec uhost]} {return}
	if {![ccopt get dronebl]} {return}
	set addr [lindex [split [dict get $userrec uhost] @] 1]
	if {[::ip::is ipv4 $addr]} {
		gotipv4 [::hexchat::prefs id] $chan $userrec $addr
	} elseif {[::ip::is ipv6 $addr]} {
		# gotipv6 [::hexchat::prefs id] $chan $userrec $addr
	} else {
		::dns::resolve $addr -type A -command [list ::dasbrain::dronebl::gotipv4-cb [::hexchat::prefs id] $chan $userrec]
		#::dns::resolve $addr -type AAAA -command [list ::dasbrain::dronebl::gotipv6-cb [::hexchat::prefs id] $chan $userrec]
	}
}

proc ::dasbrain::dronebl::gotipv4-cb {sid chan userrec token} {
	set addrs [::dns::address $token]
	::dns::cleanup $token
	if {[llength $addrs]} {
		# Simply use the first address *shrug*
		gotipv4 $sid $chan $userrec [lindex $addr 0]
	}
}

proc ::dasbrain::dronebl::gotipv4 {sid chan userrec addr} {
	dict set ::dasbrain::channels::channels $sid $chan users [dict get $userrec nick] ip $addr
	dict set userrec ip $addr
	set lookupaddr [join [lreverse [split $addr .]] .].dnsbl.dronebl.org
	::dns::resolve $lookupaddr -type A -command [list ::dasbrain::dronebl::gotdbl-response $sid $chan $userrec]
}



proc ::dasbrain::dronebl::gotdbl-response {sid chan userrec token} {
	set cfields [::hexchat::list_fields channels]
	set ctxidx [lsearch $cfields context]
	set channelidx [lsearch $cfields channel]
	set ididx [lsearch $cfields id]
	
	foreach cinfo [::hexchat::getlist channels] {
		if {[lindex $cinfo $ididx] == $sid &&
			[lindex $cinfo $channelidx] eq $chan} {
			::hexchat::setcontext [lindex $cinfo $ctxidx]
			break
		}
	}
	
	switch -exact -- [::dns::status $token] {
		ok {
			set addrs [::dns::address $token]
			if {[llength $addrs] > 0 && [regexp {127.0.0.(.*)$} [lindex $addrs 0] - reason]} {
				variable dronebl-classes
				set reason "[dict get ${dronebl-classes} $reason] ($reason)"
				set nick [dict get $userrec nick]
				dict set ::dasbrain::channels::channels $sid $chan users $nick dronebl $reason
				if {[::dasbrain::channels::meop $chan]} {
					::hexchat::command "KICK $nick DRONEBL: $reason"
				} else {
					::hexchat::print "$nick/DRONEBL\t$reason"
				}
			}
		}
		error {
			switch -exact -- [::dns::error $token] {
				{Name Error - domain does not exist} {
					# Ignore - not listed
				}
				default {
					::hexchat::print "DRONEBL Error\t[::dns::error $token]"
				}
			}
		}
	}
	::dns::cleanup $token
}