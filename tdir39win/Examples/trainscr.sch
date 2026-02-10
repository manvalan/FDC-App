#!trdir

Train: T1
	Enter: 00:01, A
	00:03, 00:04, S1
	00:07, -, S2
Script:
  OnEntry:
	do showalert T1 entered
  end

  OnStop:
	do showalert T1 stopped
  end

  OnStart:
	if random > 50
		Train.wait = 60
		do showalert delayed start by 60 seconds
	else
		do showalert T1 started
	end
  end

  OnWaiting:
	do showalert T1 waiting
  end

  OnArrived:
	do showalert T1 arrived at S2
  end
EndScript
Stock: T2
.

Train: T2
	Enter: 0:10, S2
	Wait: T1
	0:13, -, B
Script:
  OnAssign:
	do showalert T2 assigned
  end
  OnExit:
	do showalert T2 exited
  end
EndScript
.

Train: T3
	Enter: 0:12, A
	0:14, -, S1
Script:
  OnShunt:
	do showalert T3 shunting
  end
  OnReverse:
	do showalert T3 reversed
  end
EndScript
.

