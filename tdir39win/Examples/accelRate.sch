#!trdir

Type: 1 >0.5
Type: 2 >2


Train: T1
Type: 1
Enter: 00:01, W1
	00:03, 00:04, S1
	00:10, -, E1
Notes: T1 uses 0.5 accel.rate from type 1
.


Train: T2
Type: 2
Enter: 00:01, W2
	00:03, 00:04, S2
	00:10, -, E2
Notes: T2 uses 2.0 accel.rate from type 2
.


Train: T3
Type: 3
AccelRate: 3.0
Enter: 00:01, W3
	00:03, 00:04, S3
	00:10, -, E3
Notes: T3 uses 3.0 accel.rate from AccelRate: line
.


Train: T4
Type: 4
Enter: 00:01, W4
	00:03, 00:04, S4
	00:10, -, E4
Notes: T4 uses default accel.rate of 1.0
.


