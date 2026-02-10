#!trdir

Train: T1
Length: 250
	Enter: 00:01, W
	00:07, -, E2
Notes: via S1
.

Train: T2
Length: 150
Stock: T4
	Enter: 0:06, W
	0:11, -, E1
Notes: via S1
.

Train: T3
Length: 150
	Enter: 0:12, W
	0:14, 0:15, S1
	0:19, -, E2
Notes: via S1
.

Train: T4
Wait: T3
	Enter: 0:20, W
	0:23, 0:24, S2
	0:28, -, E2
Notes: via S2
.

