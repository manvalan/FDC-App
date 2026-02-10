function loadTimeDistance() {
    $.get('/war/timedist.yaml', function (data) {
    	var td = YAML.parse(data);
    	var canvas = document.getElementById('timeDistanceCanvas');
    	var gc = canvas.getContext('2d');
		gc.font = '10pt Calibri';
	    gc.fillStyle = 'blue';
        gc.lineWidth = 1;
    	var i;
    	var x;
    	var xx;
    	var stationOffset = 150;
    	var nStations = 0;
    	if(td.stations) {
    		nStations = td.stations.length;
    	}
    	for (i = 0; i < nStations; ++i) {
    		var st = td.stations[i];
    	    gc.fillText(st.name, 10, st.y);
    		gc.strokeStyle = '#404040';
    	    for(x = 0; x < 24 * 60 * 4; ++x) {
	    	    gc.beginPath();
	    	    gc.moveTo(x + stationOffset, st.y - 1);
	    	    gc.lineTo(x + stationOffset, st.y + 1);
	    	    gc.stroke();
    	    }
    	}
		gc.font = '10pt Calibri';
	    for(x = 0; x < 24; ++x) {
	    	var hr = x + ":00";
    	    gc.fillText(hr, x * 60 * 4 - 8 + stationOffset, 10);
    		gc.strokeStyle = '#808080';
	    	gc.beginPath();
	    	gc.moveTo(x * 60 * 4 + stationOffset, 20);
	    	gc.lineTo(x * 60 * 4 + stationOffset, 2000);
	    	gc.stroke();
			gc.strokeStyle = '#40c040';
	    	for(xx = 10; xx < 60; xx += 10) {
		    	gc.beginPath();
		    	gc.moveTo((x * 60 + xx) * 4 + stationOffset, 20);
		    	gc.lineTo((x * 60 + xx) * 4 + stationOffset, 2000);
		    	gc.stroke();
	    	}
	    }
	    var nTrains = 0;
	    if (td.trains) {
	    	nTrains = td.trains.length;
	    }
        gc.lineWidth = 2;
    	for (i = 0; i < nTrains; ++i) {
    		var tr = td.trains[i];
    		gc.beginPath();
    		gc.moveTo(tr.x0, tr.y0);
    		gc.lineTo(tr.x1, tr.y1);
    		gc.strokeStyle = '#' + ("000000" + tr.color.toString(16)).substr(-6);
    		gc.stroke();
    	}
    });
}
