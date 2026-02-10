#!trdir

Train: T1
Type: 1
Enter: 00:01, W1
	00:03, -, S1
Stock: T2
Script:
OnArrived:
  do reverse T1
  do assign T1, T2
  do traininfo T2
end
EndScript
.


Train: T2
Type: 2
Wait: T1
Enter: 00:10, S1
	00:13, -, W1
.


Train: T3
Type: 1
Enter: 00:15, W1
	00:18, 00:19, S1
	-, 00:22, S12
	00:24, 00:25, S13
	00:28, -, S14
Script:
OnStart:
    if Train.nextStation = S12
	do showalert NextStation S12
    end
    if Train.nextStation = S13
	do showalert NextStation S13
    end
    if Train.nextStation = S14
	do showalert NextStation S14
    end
end
EndScript
.

