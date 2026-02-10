#!trdir

# We have a train that's supposed to stop at S@1
# We send it to S@2 and E2, and verify that the
# JSON returned by /poll reflects this

Requires: 3.9.1

Train: Train1
Enter: 00:01, W
	00:04, 00:06, S@1
	00:10, -, E1
.

Train: Train2
Enter: 00:07, W
    -, 00:08, S@2
	00:10, -, E2
.

