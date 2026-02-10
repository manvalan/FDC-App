#!trdir

# Two trains traveling in opposite directions
# on track sections with directional speed limits

Requires: 3.9.3

Train: Train1
Enter: 00:01, W
	00:06, -, E
.

Train: Train2
Enter: 00:08, E
	00:13, -, W
.

# Use script associated with button to assign (x,y) Train4

Train: Train3
Length: 200
Enter: 00:14, W2
	00:16, -, S
Stock: Train4
.

Train: Train4
Length: 200
Wait: Train3
Enter: 00:19, S
	00:21, -, E2
.

