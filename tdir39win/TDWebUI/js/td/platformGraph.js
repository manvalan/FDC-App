function loadPlatforms() {
    $.get('/war/platforms.yaml', function (data) {
    	var td = YAML.parse(data);
    	var canvas = document.getElementById('platformsCanvas');
    	var gc = canvas.getContext('2d');

        if (!td || !td.stations) {
            gc.fillText("No stations", 10, 40);
            return;
        }

    	// draw background
    	gc.fillStyle = "white";
    	gc.fillRect(0, 0, 3000, 2000);
    	
    	var stationOffset = 200;
    	// draw background
    	gc.fillStyle = "#e0e0e0";
    	gc.fillRect(stationOffset, 20, 24 * 60 * 2, td.stations.length * 20);

    	gc.font = '10pt Calibri';
	    gc.fillStyle = 'black';
        gc.lineWidth = 1;
    	var i;
    	var x;
    	var y;
    	var xx;
    	for (i = 0; i < td.stations.length; ++i) {
    		y = i * 20 + 40;
    		var st = td.stations[i];
    	    gc.fillText(st.name, 10, y);
    		gc.strokeStyle = '#404040';
    		gc.beginPath();
    		gc.moveTo(stationOffset, y);
    		gc.lineTo(24 * 60 * 2 + stationOffset, y)
    		gc.stroke();
    	}
		gc.font = '10pt Calibri';
	    for(x = 0; x < 24; ++x) {
	    	var hr = x + ":00";
    	    gc.fillText(hr, x * 60 * 2 - 8 + stationOffset, 10);
    		gc.strokeStyle = '#808080';
	    	gc.beginPath();
	    	gc.moveTo(x * 60 * 2 + stationOffset, 20);
	    	gc.lineTo(x * 60 * 2 + stationOffset, td.stations.length * 20 + 20);
	    	gc.stroke();
			gc.strokeStyle = '#8080ff';
	    	for(xx = 10; xx < 60; xx += 10) {
		    	gc.beginPath();
		    	gc.moveTo((x * 60 + xx) * 2 + stationOffset, 20);
		    	gc.lineTo((x * 60 + xx) * 2 + stationOffset, td.stations.length * 20 + 20);
		    	gc.stroke();
	    	}
	    }
    	for (i = 0; i < td.trains.length; ++i) {
    		var tr = td.trains[i];
    		gc.beginPath();
    		gc.moveTo(tr.x0 + stationOffset - 145, tr.y + 20);
    		gc.lineTo(tr.x1 + stationOffset - 145, tr.y + 20);
    		gc.strokeStyle = '#' + ("000000" + tr.color.toString(10)).substr(-6);
   	        gc.lineWidth = 3;
    		gc.stroke();
    	}
    });
}
