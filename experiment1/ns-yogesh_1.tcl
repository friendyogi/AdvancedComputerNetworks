#Create a simulator object
set ns [new Simulator]

#Define separate colors for data flow (for NAM)
$ns color 1 Blue
$ns color 2 Red

#Open the trace files
#file for capturing all default trace
set tracefile1 [open out.tr w]
$ns trace-all $tracefile1

#file for capturing throughput 
set tracefile2 [open throughput.xg w]


#Open the NAM trace file
set namfile1 [open out.nam w]
$ns namtrace-all $namfile1

#Define a 'finish' procedure
proc finish {} {
        global ns tracefile1 namfile1 
        $ns flush-trace
        #Close the NAM trace file
        close $namfile1
	#Close the trace file
	close $tracefile1
        #Execute NAM on the trace file
        exec nam out.nam &
	# Open the throughput graph, column 1 against 2 and then plot column 1 against 3, using different color
 	exec ~/Downloads/XGraph4.38_linux64/bin/xgraph -pl -columns 1 2 -color blue throughput.xg -columns 1 3 -color green throughput.xg &
	# Open the CWND graphs
 	exec ~/Downloads/XGraph4.38_linux64/bin/xgraph -pl -color red output1.xg &
 	exec ~/Downloads/XGraph4.38_linux64/bin/xgraph -pl -color orange output2.xg &
        exit 0
}

#Create four nodes
set n0 [$ns node]
set n1 [$ns node]
set n2 [$ns node]
set n3 [$ns node]

#Create links between the nodes
$ns duplex-link $n0 $n1 2Mb 100ms DropTail
$ns duplex-link $n1 $n2 2Mb 100ms SFQ
$ns duplex-link $n3 $n1 2Mb 100ms DropTail

#Give node position (for NAM)
$ns duplex-link-op $n0 $n1 orient right-down
$ns duplex-link-op $n3 $n1 orient right-up
$ns duplex-link-op $n1 $n2 orient right

#Set queue lenght to 10 packages for all links
$ns queue-limit $n0 $n1 10
$ns queue-limit $n1 $n2 10
$ns queue-limit $n3 $n1 10

#Setup a TCP connection
#Sender
set tcp1 [new Agent/TCP/Linux]
$tcp1 set class_ 1
# window_ is upperbound for congestion window. Default is 20
$tcp1 set window_ 20
$ns attach-agent $n0 $tcp1
#Receiver
set sink1 [new Agent/TCPSink]
$ns attach-agent $n2 $sink1
#Connect Sender to Receiver
$ns connect $tcp1 $sink1
$tcp1 set fid_ 1

#Setup FTP1 over TCP1 connection
set ftp1 [new Application/FTP]
$ftp1 attach-agent $tcp1
$ftp1 set type_ FTP1

#Setup a TCP connection
#Sender
set tcp2 [new Agent/TCP/Linux]
$tcp2 set class_ 2
$tcp2 set window_ 20
$ns attach-agent $n3 $tcp2
#Receiver
set sink2 [new Agent/TCPSink]
$ns attach-agent $n2 $sink2
#Connect Sender to Receiver
$ns connect $tcp2 $sink2
$tcp2 set fid_ 2

#Setup FTP2 over TCP2 connection
set ftp2 [new Application/FTP]
$ftp2 attach-agent $tcp2
$ftp2 set type_ FTP2

proc bandwidth {} {
    global sink1 sink2 tracefile2
    #Get an instance of the simulator
    set sn [Simulator instance]
    #Set the time after which the procedure should be called again
    set time 0.5
    #How many bytes have been received by the traffic sinks?
    set bandwidth1 [$sink1 set bytes_]
    set bandwidth2 [$sink2 set bytes_]
    #Get the current time
    set now [$sn now]
    #Calculate the bandwidth (in MBit/s) and write it to the files
    # value / time x 8 / 100000
    # output file will have 3 columns - time, throughput1 AND throughput2
    puts $tracefile2 "$now [expr $bandwidth1/$time*8/1000000] [expr $bandwidth2/$time*8/1000000]"
    #Reset the bytes_ values on the traffic sinks
    $sink1 set bytes_ 0
    $sink2 set bytes_ 0
    #Re-schedule the procedure
    $sn at [expr $now+$time] "bandwidth"
}

#Schedule events for the FTP agents
# call the record procedure to record the bandwidth
$ns at 0.0 "bandwidth"
# start both ftp sessions at the same time
$ns at 0.0 "$ftp1 start"
$ns at 0.0 "$ftp2 start"
# end the ftp sessions
$ns at 80.0 "$ftp1 stop"
$ns at 60.0 "$ftp2 stop"

#Call the finish procedure after 100 seconds of simulation time
$ns at 100.0 "finish"


# Plot CWND from TCP agent
proc plotGraph {tcpagent output} {
	global ns
	set now [$ns now]
	set cwnd [$tcpagent set cwnd_]
	# Print time now and value of cwnd into a file
	puts $output "$now $cwnd"
	# At now + 0.1 second
	$ns at [expr $now+0.1] "plotGraph $tcpagent $output"
}


# Write CWND output to two files
set output1 [open "output1.xg" w]
set output2 [open "output2.xg" w]

# Run the procedure to plot CWND
$ns at 0.0 "plotGraph $tcp1 $output1"
$ns at 0.0 "plotGraph $tcp2 $output2"

#Run the simulation
$ns run

