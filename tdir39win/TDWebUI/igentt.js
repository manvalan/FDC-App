var ifrmStations;
var stationsList;
var allTrains = [];
var nextStation = 0;
var nextTrain = 0; 

String.prototype.capitalize = function() {
    return this.replace(/(?:^|\s)\S/g, function(a) { return a.toUpperCase(); });
};

function escapeRegExp(string) {
    return string.replace(/([.*+?^=!:${}()|\[\]\/\\])/g, "\\$1");
}

function replaceAll(string, find, replace) {
	return string.replace(new RegExp(escapeRegExp(find), 'g'), replace);
}

function loadStations() {
	allTrains = [];
	$.get( "/tt/stations.yaml", function( data ) {
		var items = [];
		if (data != "") {
			stationsList = YAML.parse(data);
			if(stationsList.files) {
				$.each(stationsList.files, function( key, val ) {
					items.push("<li>" + val.name + "</li>");
				});
			}
		}
		$("#stationsList").html(items.join("\n"));
		nextStation = 0;
		if (stationsList.files.length > 0) {
			getStationFile(0);
		}
	}).done(function() {
		console.log("done");
	}).fail(function() {
		$("#status").html("<p>Could not retrieve the information about this scenario.");
	});
}

function getStationFile(index) {
	var url = stationsList.files[index].url;
//	$("#status").html("<p class='bg-info'>Reading Station " + stationsList.files[index].name + " (" + (index + 1) + "/" + stationsList.files.length + ")");
	var msg = stationsList.files[index].name;
	var pct = index * 100 / stationsList.files.length;
    $("#status").html("<div class='panel panel-info'>Station " + msg + "<p><div class='progress'><div class='progress-bar' role='progressbar' aria-valuenow='" + (index + 1) + "' aria-valuemin='0' aria-valuemax='" + stationsList.files.length + "' style='width: " + pct + "%;'> </div></div></div>");
	if (index == 0) {
		$("#ifrmstats").load(parseStation);
	}
	$("#ifrmstats").attr('src', url);
}

function addTrain(tr) {
	var i;
	for(i = 0; i < allTrains.length; ++i) {
		if(tr.name == allTrains[i].name) {
			return;
		}
	}
	allTrains.push(tr);
}

function parseStation() {
	var fdoc = $("#ifrmstats")[0].contentWindow.document;
	var isE656 = $(fdoc).find(".collegamenti-banner");
	if (isE656 && isE656.length > 0) {
	    $(".train-number", fdoc).each(function() {
	        var trainRow = {};
            $(this).find("a").each(function() {
				trainRow.url = $(this).attr('href');
				if(!trainRow.url.startsWith("http"))
					trainRow.url = "http://www.e656.net" + trainRow.url;
                trainRow.name = $(this).text().replace("\n","").replace(" ", "");
            });
            addTrain(trainRow);
	    });
	} else {
    	var frmcont = fdoc.getElementById("Contents");
    	var trinfo = $(frmcont).find('.hfs_stboard');
    	var rows = $('tr', trinfo);
    	$('tr', trinfo).each(function() {
    		var trainRow = { };
    		$(this).find("td.journey").each(function(cellIndex) {
    			$(this).find("a").each(function() {
    				trainRow.url = $(this).attr('href');
    				trainRow.name = $(this).text().replace("\n","").replace(" ", "");
    			});
    			addTrain(trainRow);
    	    });
    	});
	}
	var content = JSON.stringify(allTrains, 4);
	result = document.getElementById("CGResult");
	$(result).html(content);

	var allNames = [];
	for (i = 0; i < allTrains.length; ++i) {
		var tr = allTrains[i];
		if(tr && tr.name) {
			allNames.push("<li>" + tr.name + "</li>\n");
		}
	}
	$("#trainsList").html(allNames.join(""));

	++nextStation;
	if (nextStation < stationsList.files.length) {
		// we want to slow down the requests to avoid Denial of Service errors
		setTimeout(function() {
			getStationFile(nextStation);
		}, 1500);
	} else {
		nextTrain = 0;
		getTrainFile(nextTrain);
	}
}

function getTrainFile(index) {
	var url = allTrains[index].url;
	var name = allTrains[index].name;
//	$("#status").html("<p class='bg-info'>Reading train " + name + " (" + (index + 1) + "/" + allTrains.length + ")");
	var pct = index * 100 / allTrains.length;
    $("#status").html("<div class='panel panel-info'>Train " + name + "<p><div class='progress'><div class='progress-bar' role='progressbar' aria-valuenow='" + (index + 1) + "' aria-valuemin='0' aria-valuemax='" + allTrains.length + "' style='width: " + pct + "%;'> </div></div></div>");
	if (index == 0) {
//		iframecontent = "<iframe name='ifrmstats' id='ifrmstats' width='100%' height='400px' style='background: #e0e0e0'></iframe>\n";
//		$("#ifrmstatsdiv").html(iframecontent);
		$("#ifrmtrain").load(parseTrain);
	}
	$.get('/tt/recv.yaml', name +"@" + url, function(data) {
	    //console.log(data);
	    var localUrl = '/gentt/trains/' + name + ".html";
	    $("#ifrmtrain").attr('src', localUrl);
	});
}

function stripBlanks(s) {
	var i;
	var d = "";
	for(i = 0; i < s.length; ++i) {
		if(s[i] != " " && s[i] != "\n" && s.charCodeAt(i) != 160)
			d = d + s[i];
	}
	if(d.length == 1)
		console.log(d.charCodeAt(0));
	return d;
}

function stripNL(s) {
    var i;
    var d = "";
    s = s.trim();
    for(i = 0; i < s.length; ++i) {
        if(s[i] != "\n")
            d = d + s[i];
    }
    if(d.length == 1)
        console.log(d.charCodeAt(0));
    return d;
}

function e656Time(s) {
	return replaceAll(s, '.', ':');
}

function parseTrain() {
    var result = document.getElementById("CGResult");
    var allStops = [];
 
    var fdoc = $("#ifrmtrain")[0].contentWindow.document;
    var isE656 = $(fdoc).find(".collegamenti-banner");
    if(isE656 && isE656.length > 0) {
        var tables = $(fdoc).find(".list-table");
        var t;
        for(t = 0; t < tables.length; ++t) {
            var tab = tables[t];
            $(tab).find("tr").each(function() {
                var trainStop = { };
                $(this).find("td").each(function(cellIndex) {
                    if(cellIndex == 0) {
                        trainStop.name = stripNL($(this).text()).toLowerCase().capitalize();
                    } else if (cellIndex == 1) {
                        trainStop.arr = e656Time(stripBlanks($(this).text()));
                    } else if (cellIndex == 2) {
                        trainStop.dep = e656Time(stripBlanks($(this).text()));
                    } else if (cellIndex == 3) {
						bin = stripBlanks($(this).text());
						if(bin.length > 0 && bin[0] >= '0' && bin[0] <= '9') {
							trainStop.name += "@" + bin;
						}
					}
                });
                if(trainStop.name)
                    allStops.push(trainStop);
            });
            break;
        }
    } else {
        var frmcont = fdoc.getElementById("Contents");
        var trinfo = $(frmcont).find('.hfs_traininfo');
        var rows = $('tr', trinfo);
        var s;
        $('tr', trinfo).each(function() {
            var trainStop = { };
            $(this).find("td").each(function(cellIndex) {
                if($(this).hasClass("location")) {
                    $(this).find("a").each(function() {
                        trainStop.link = $(this).attr('href');
                        trainStop.name = $(this).text().replace("\n", "");
                    });
                } else if ($(this).hasClass("arr time")) {
                    s = stripBlanks($(this).text());
                    if(s != "")
                        trainStop.arr = s;
                } else if ($(this).hasClass("dep time")) {
                    s = stripBlanks($(this).text());
                    if(s != "")
                        trainStop.dep = s;
                }
            });
            if(trainStop.name)
                allStops.push(trainStop);
        });
    }
    allTrains[nextTrain].stops = allStops;
    genSchedule();
    var content = JSON.stringify(allStops, 4);
    $(result).html(content);
    ++nextTrain;
    if (nextTrain < allTrains.length) {
		// we want to slow down the requests to avoid Denial of Service errors
		setTimeout(function() {
			getTrainFile(nextTrain);
		}, 1500);
    } else {
        $("#status").html("<div class='panel panel-success'><b>Done reading all trains.</b><p><div class='progress'><div class='progress-bar' role='progressbar' aria-valuenow='100' aria-valuemin='0' aria-valuemax='100' style='width: 100%;'><span class='sr-only'>100% </span>  </div></div></div>");
    }
}   

function formatHour(h) {
	return h; 
}

function genSchedule() {
	var sch = "#!trdir\n\n";
	var i;
	for (i = 0; i < allTrains.length; ++i) {
		var tr = allTrains[i];
		if(!tr.name || !tr.stops)
			continue;
		var s = "Train: " + tr.name + "\n";
		var stops = tr.stops;
		for (st = 0; st < stops.length; ++st) {
			if(st == 0) {
				s = s + "Enter: " + formatHour(stops[st].dep) + ", " + stops[st].name + "\n"; 
			} else if(!stops[st].dep) {
				s = s + "   " + formatHour(stops[st].arr) + ", -, " + stops[st].name + "\n";
			} else {
				s = s + "   " + formatHour(stops[st].arr) + ", " + formatHour(stops[st].dep) + ", " + stops[st].name + "\n";
			}
		}
		s = s + ".\n\n";
		sch += s;
	}
	$("#schedule").html(sch);
}