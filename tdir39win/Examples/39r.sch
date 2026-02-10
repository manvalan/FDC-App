#!trdir

# Here we use the | character to separate
# allowed exit points (no penalties for these exit points)

Train: Train1
Enter: 00:01, A
	00:04, 00:06, S2
	00:10, -, B|C
.

Train: Train2
Enter: 00:10, A
	00:12, 00:13, S1
	00:16, -, B
.

# The same | character can be used to specify
# alternative entry points (if one entry point
# is invalid, avoids having delayed entry penalties)

Train: Train3
Enter: 00:20, B|C
    00:24, -, S2
.

# Multiple alternative entry points are separated
# by a comma character. Here Train4 can enter
# from B, C or D

Train: Train4
Enter: 00:23, B|C|D
    00:29, -, S2
.

