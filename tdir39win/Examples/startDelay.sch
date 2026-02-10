#!trdir

Type: 2 +20
Type: 1 +10


Train: T1
Enter: 00:01, A
	00:03, 00:04, S1
	00:07, -, B
Notes: T1 uses default type, i.e. 1 it should get a StartDelay == 10
.


Train: T2
Type: 2
Enter: 00:10, A
	00:13, 00:14, S1
	00:17, -, B
Notes: T2 uses specific type 2. It should get a StartDelay == 20
.

Train: T3
Type: 3
Enter: 00:20, A
	00:23, 00:24, S1
	00:27, -, B
Notes: T3 uses specific type 3. It should not get any StartDelay
.

Train: T4
Type: 4
StartDelay: 30
Enter: 00:30, A
	00:33, 00:34, S1
	00:37, -, B
Notes: T4 uses specific type 4 and specifies a local StartDelay == 30
.

