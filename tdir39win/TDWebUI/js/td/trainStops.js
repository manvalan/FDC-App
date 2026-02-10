var trainStopsTrain;        // TODO: make local to view instance
var trainStopsLink;

// update left panel of Train Stops view
function updateTrainsStop() {
    var schedFilter = $('#trainSelectorSearchInput').val();
    $('#trainSelectorSearchInput').on('input', function() {
        schedFilter = $(this).val(); // get the current value of the input field.
        updateTrainSelectorList(schedFilter);
    });
    updateTrainSelectorList(schedFilter);
}

function updateTrainSelectorList(filtr) {
	$.getJSON( "/war/trains.json", function( data ) {
		var titems = [];
		var i;
		for(i = 0; i < data.trains.length; ++i) {
		    var val = data.trains[i];
		    if(filtr && filtr.length > 0 && val.name.indexOf(filtr) < 0)
		        continue;
		    titems.push("<li class='trainListItem' onclick='selectedTrainStops(\"" + val.link + "\", " + i + ");'>" + val.name + "</li>\n");
		}
		$("#trainSelector").html(titems.join(""));
	}).fail(function() {
		console.log("fail");
	});
}

function selectTrainInTrainList(indx) {
    var i = 0;
	$(".trainListItem").each(function() {
		if(i == indx) {
			this.style.color = "blue";
			$(this).css("font-weight", "bold")
		} else {
			this.style.color = "black";
			$(this).css("font-weight", "normal")
		}
		++i;
	});
}

// update right panel of Train Stops view
function selectedTrainStops(link, indx) {
    trainStopsTrain = indx;
    trainStopsLink = link;
    var schedFilter = $('#trainStopsSearchInput').val();
    $('#trainStopsSearchInput').on('input', function() {
        schedFilter = $(this).val(); // get the current value of the input field.
        updateTrainStops(schedFilter);
    });
    updateTrainStops(schedFilter);
}

function updateTrainStops(filtr) {
	$.when( $.getJSON('/war/stops.json?t=' + trainStopsLink), $.getJSON('/war/trains.json') ).then(function( stops, trains ) {
		
		var items = [];
		var i;
		for(i = 0; i < stops[0].stops.length; ++i) {
		    var val = stops[0].stops[i];
		    if(filtr && filtr.length > 0) {
		        if(val.station.indexOf(filtr) < 0 &&
	                val.arrival.indexOf(filtr) < 0 &&
	                val.departure.indexOf(filtr) < 0)
		            continue;
		    }
		    items.push("<tr onclick='selectedStationItem(\"" + val.stationlink + "\", \"" + val.station +
		    		"\");'><td>" + val.station + "</td><td>" + val.arrival + "</td><td>" + val.departure +
		    		"</td><td>" + val.minstop + "</td></tr>\n");
		}
        $("#trStopsTable").colResizable({liveDrag: true, postbackSafe: true });
		$("#trStopsTable tbody").html(items.join("\n"));
		selectTrainInTrainList(trainStopsTrain);
    });
}

