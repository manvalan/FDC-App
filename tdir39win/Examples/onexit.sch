#!trdir

Train: T1
Length: 250
	Enter: 00:01, A
	00:03, 00:04, S1
	00:07, -, B
.

Train: T2
Length: 150
Stock: T4
	Enter: 0:10, A
	0:13, -, S1
.

Train: T3
Length: 150
	Enter: 0:12, A
	0:14, -, S0
.

Train: T4
Wait: T3
	Enter: 0:20, S1
	0:25, -, B
.

Train: T5
	Enter: 0:29, A
	0:32, -, S0
Stock: T6
.
Train: T6
	Enter: 0:36, S0
	0:45, -, B
Wait: T5
Script:
OnAssign:
    do split T6,1
    do shunt T6
end
EndScript
.

