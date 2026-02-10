#!trdir

# DefaultSpeed specifies to use the highest train type's speed
# instead of the default, which if the speed of type 1 trains

#DefaultSpeed: last

# Trains with a mix of motive powers, including multi-traction
# trains (multi-voltage and electric+diesel power)

Train: T3kV
Type: 1
Power: 3000V
Enter: 00:01, W3kV
	00:05, -, E3kV
.

Train: T10kV
Power: 10000V
Type: 2
Enter: 00:05, W10kV
	00:10, -, E10kV
.

Train: T3kV10kV
Type: 3
Power: 3000V,10000V
Enter: 00:10, W3kV
	00:15, -, E10kV
.

Train: T3kVDiesel
Power: 3000V,Diesel
Enter: 00:15, W3kV
	00:20, -, ED
.

Train: TAny
Enter: 00:20, W10kV
	00:25, -, ED
.

