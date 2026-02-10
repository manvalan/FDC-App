var canvasClick;
var canvasMouseMove;

var drawingTools = 0;

var zooming;
var coords;

var ctx;
var shapes = { };
var NORTH = { x: 4, y: 0 };
var SOUTH = { x: 4, y: 9 };
var WEST = { x: 0, y: 4 };
var EAST = { x: 9, y: 4 };
var NORTHWEST = { x: 0, y: 0 };
var NORTHEAST = { x: 9, y: 0 };
var SOUTHWEST = { x: 0, y: 9 };
var SOUTHEAST = { x: 9, y: 9 };
var CENTER = { x: 4, y: 4 };
var tdOptions;
var bgColor;

function getRGBAstring(col) {
    return 'rgba(' + ((col >> 16) & 0xff) + ', ' + ((col >> 8) & 0xff) + ', ' + (col & 0xff) + ', 1)';
}

function drawSegs(x, y, segs) {
    var mult = drawingTools ? 3 : 1;
    var xpos = x * 9 * mult;
    var ypos = y * 9 * mult;
    var i;
    // TODO: use path instead of segs
    for (i = 0; i < segs.length; i += 2) {
        ctx.beginPath();
        ctx.moveTo(xpos + segs[i].x * mult, ypos + segs[i].y * mult);
        ctx.lineTo(xpos + segs[i + 1].x * mult, ypos + segs[i + 1].y * mult);
        ctx.stroke();
    }
}

function drawTrack(t, dir) {
    ctx.strokeStyle = getRGBAstring(t.color); //'rgba(0, 0, 255, 1)';
    switch(dir) {
    case 8:     // n-s
        drawSegs(t.x, t.y, [ NORTH, SOUTH ])
        break;
    case 1:     // w-e
        drawSegs(t.x, t.y, [ WEST, EAST ])
        break;
    case 2:     // nw-se
        drawSegs(t.x, t.y, [ NORTHWEST, SOUTHEAST ]);
        break;
    case 3:     // sw-ne
        drawSegs(t.x, t.y, [ SOUTHWEST, NORTHEAST ]);
        break;
    case 4:     // w-ne
        drawSegs(t.x, t.y, [ WEST, CENTER, CENTER, NORTHEAST ]);
        break;
    case 5:     // w-se
        drawSegs(t.x, t.y, [ WEST, CENTER, CENTER, SOUTHEAST ]);
        break;
    case 6:     // nw-e
        drawSegs(t.x, t.y, [ NORTHWEST, CENTER, CENTER, EAST ]);
        break;
    case 7:     // sw-e
        drawSegs(t.x, t.y, [ SOUTHWEST, CENTER, CENTER, EAST ]);
        break;
    case 12:        // nw-s
        drawSegs(t.x, t.y, [ NORTHWEST, CENTER, CENTER, SOUTH ]);
        break;
    case 11:        // sw-n
        drawSegs(t.x, t.y, [ SOUTHWEST, CENTER, CENTER, NORTH ]);
        break;
    case 14:        // s-ne
        drawSegs(t.x, t.y, [ SOUTH, CENTER, CENTER, NORTHEAST ]);
        break;
    case 13:        // n-se
        drawSegs(t.x, t.y, [ NORTH, CENTER, CENTER, SOUTHEAST ]);
        break;
    case 20:        // w-e-nw-se
        drawSegs(t.x, t.y, [ WEST, EAST, NORTHWEST, SOUTHEAST ]);
        break;
    case 21:        // w-e-sw-ne
        drawSegs(t.x, t.y, [ WEST, EAST, SOUTHWEST, NORTHEAST ]);
        break;
    case 22:        // nw-se-sw-ne
        drawSegs(t.x, t.y, [ NORTHWEST, SOUTHEAST, SOUTHWEST, NORTHEAST ]);
        break;
    case 23:        // w-e-n-s
        drawSegs(t.x, t.y, [ WEST, EAST, NORTH, SOUTH ]);
        break;
    case 24:        // n-s-sw-ne
        drawSegs(t.x, t.y, [ NORTH, SOUTH, SOUTHWEST, NORTHEAST ]);
        break;
    case 25:        // n-s-nw-se
        drawSegs(t.x, t.y, [ NORTH, SOUTH, NORTHWEST, SOUTHEAST ]);
        break;
    }
}

function drawSwitch(t) {
    var mult = drawingTools ? 3 : 1;
    var xpos = t.x * 9 * mult;
    var ypos = t.y * 9 * mult;
    ctx.strokeStyle = getRGBAstring(t.color); //'rgba(0, 0, 255, 1)';
    ctx.beginPath();
    ctx.moveTo(xpos, ypos);
    ctx.lineTo(xpos + 9 * mult, ypos);
    ctx.lineTo(xpos + 9 * mult, ypos + 9 * mult);
    ctx.lineTo(xpos, ypos + 9 * mult);
    ctx.lineTo(xpos, ypos);
    ctx.lineWidth = 0.5;
    ctx.stroke();
    ctx.lineWidth = 2;
    
    switch(t.dir) {
    case 0:     // w-e/w-ne
        if(editing) {
            drawTrack(t, 1);
            drawTrack(t, 4);
        } else
            drawTrack(t, t.switched ? 4 : 1);
        break;
    case 1:     // w-e/nw-e
        if(editing) {
            drawTrack(t, 1);
            drawTrack(t, 6);
        } else
            drawTrack(t, t.switched ? 6 : 1);
        break;
    case 2:     // w-e/w-se
        if(editing) {
            drawTrack(t, 1);
            drawTrack(t, 5);
        } else
            drawTrack(t, t.switched ? 5 : 1);
        break;
    case 3:     // w-e/sw-e
        if(editing) {
            drawTrack(t, 1);
            drawTrack(t, 7);
        } else
            drawTrack(t, t.switched ? 7 : 1);
        break;
    case 4:     // sw-ne/sw-e
        if(editing) {
            drawTrack(t, 3);
            drawTrack(t, 7);
        } else
            drawTrack(t, t.switched ? 7 : 3);
        break;
    case 5:     // sw-se/w-ne
        if(editing) {
            drawTrack(t, 3);
            drawTrack(t, 4);
        } else
            drawTrack(t, t.switched ? 4 : 3);
        break;
    case 6:     // nw-se/nw-e
        if(editing) {
            drawTrack(t, 2);
            drawTrack(t, 6);
        } else
            drawTrack(t, t.switched ? 6 : 2);
        break;
    case 7:     // nw-se/w-se
        if(editing) {
            drawTrack(t, 2);
            drawTrack(t, 5);
        } else
            drawTrack(t, t.switched ? 5 : 2);
        break;
    case 8:     // w-e/sw-ne/w-ne/sw-e
        if(editing) {
            drawSegs(t.x * mult, t.y * mult, [ WEST, NORTHEAST, SOUTHWEST, EAST ]);
            drawTrack(t, 21);
            break;
        }
        if(t.switched) {
            drawSegs(t.x, t.y, [ WEST, NORTHEAST, SOUTHWEST, EAST ]);
        } else {
            drawTrack(t, 21);
        }
        break;
    case 9:     // w-e/nw-se/w-se/nw-e
        if(editing) {
            drawSegs(t.x * mult, t.y * mult, [ WEST, SOUTHEAST, NORTHWEST, EAST ]);
            drawTrack(t, 20);
            break;
        }
        if(t.switched) {
            drawSegs(t.x, t.y, [ WEST, SOUTHEAST, NORTHWEST, EAST ]);
        } else {
            drawTrack(t, 20);
        }
        break;
    case 10:        // w-se/w-ne
        if(editing) {
            drawTrack(t, 4);
            drawTrack(t, 5);
        } else
            drawTrack(t, t.switched ? 5 : 4);
        break;
    case 11:        // nw-e/sw-e
        if(editing) {
            drawTrack(t, 6);
            drawTrack(t, 7);
        } else
            drawTrack(t, t.switched ? 7 : 6);
        break;
    case 12:        // n-s/n-sw
        if(editing) {
            drawTrack(t, 8);
            drawTrack(t, 11);
        } else
            drawTrack(t, t.switched ? 11 : 8);
        break;
    case 13:        // n-s/n-se
        if(editing) {
            drawTrack(t, 8);
            drawTrack(t, 13);
        } else
            drawTrack(t, t.switched ? 13 : 8);
        break;
    case 14:        // n-s/nw-s
        if(editing) {
            drawTrack(t, 8);
            drawTrack(t, 12);
        } else
            drawTrack(t, t.switched ? 12 : 8);
        break;
    case 15:        // n-s/ne-s
        if(editing) {
            drawTrack(t, 8);
            drawTrack(t, 14);
        } else
            drawTrack(t, t.switched ? 14 : 8);
        break;
    case 16:        // n-s/sw-ne/sw-n/s-ne
        if(editing) {
            drawSegs(t.x * mult, t.y * mult, [ SOUTHWEST, NORTH, SOUTH, NORTHEAST ]);
            drawTrack(t, 24);
        } else if(t.switched) {
            drawSegs(t.x, t.y, [ SOUTHWEST, NORTH, SOUTH, NORTHEAST ]);
        } else {
            drawTrack(t, 24);
        }
        break;
    case 17:        // n-s/nw-se/nw-s/n-se
        if(editing) {
            drawSegs(t.x * mult, t.y * mult, [ NORTHWEST, SOUTH, NORTH, SOUTHEAST ]);
            drawTrack(t, 25);
        } else if(t.switched) {
            drawSegs(t.x, t.y, [ NORTHWEST, SOUTH, NORTH, SOUTHEAST ]);
        } else {
            drawTrack(t, 25);
        }
        break;
    case 18:        // sw-ne/sw-n
        if(editing) {
            drawTrack(t, 3);
            drawTrack(t, 11);
        } else
            drawTrack(t, t.switched ? 11 : 3);
        break;
    case 19:        // sw-ne/s-ne
        if(editing) {
            drawTrack(t, 3);
            drawTrack(t, 14);
        } else
            drawTrack(t, t.switched ? 14 : 3);
        break;
    case 20:        // nw-se/n-se
        if(editing) {
            drawTrack(t, 2);
            drawTrack(t, 13);
        } else
            drawTrack(t, t.switched ? 13 : 2);
        break;
    case 21:        // nw-se/nw-s
        if(editing) {
            drawTrack(t, 2);
            drawTrack(t, 12);
        } else
            drawTrack(t, t.switched ? 12 : 2);
        break;
    case 22:        // s-ne/s-nw
        if(editing) {
            drawTrack(t, 14);
            drawTrack(t, 12);
        } else
            drawTrack(t, t.switched ? 12 : 14);
        break;
    case 23:        // n-se/n-sw
        if(editing) {
            drawTrack(t, 13);
            drawTrack(t, 11);
        } else
            drawTrack(t, t.switched ? 11 : 13);
        break;
    }
}

function drawText(t, dir) {
    var y = t.y * 9;
    if(dir) {
        y += 6;
        ctx.font = "5px Arial";
    } else {
        ctx.font = "10px Arial";
        y += 8;
    }
    ctx.fillStyle = "black";    
    ctx.fillText(t.text, t.x * 9, y);
}

function drawElement(t) {
    switch(t.type) {
    case 1:     // Track
        drawTrack(t, t.dir);
        break;
    case 2:
        drawSwitch(t, t.dir);
        break;
    case 3:     // platform
        break;
    case 10:
    case 6:     // text
        drawText(t, t.dir);
        break;
    default:
        return;
    }
}

var layoutElements;

function updateLayout(elements, trains) {
    var c = document.getElementById("canvas");
    if(!c)
        return;
    ctx = c.getContext("2d");
    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, c.width, c.height);
    var s;
    for(s = 0; s < elements.length; ++s) {
        var shp = elements[s];
        var img = shapes[shp.shape];
        if(img) {
            ctx.fillStyle = bgColor;
            ctx.putImageData(img.imagedata, shp.x * 9, shp.y * 9);
            var txt = shp.text;
            if(!txt) continue;
            if(img.id == "itinButton" && txt.indexOf("@") >= 0) {
            	txt = txt.substring(txt.indexOf("@") + 1);
            }
            drawText({ x: shp.x + 1, y: shp.y, text: txt}, 0);
            continue;
        }
        drawElement(shp);
    }
    if(!trains)
        return;
    for(s = 0; s < trains.length; ++s) {
        var shp = trains[s].loco;
        if(shp) {
            var img = shapes[shp.shape];
            if(img) {
                ctx.fillStyle = bgColor;
                ctx.putImageData(img.imagedata, shp.x * 9, shp.y * 9);
            }
        }
        shp = trains[s].car;
        if(!shp)
            continue;
        img = shapes[shp.shape];
        if(img) {
            ctx.fillStyle = bgColor;
            ctx.putImageData(img.imagedata, shp.x * 9, shp.y * 9);
        }
    }
}

function getLayout() {
    
    $.get("/war/layout.json", function(data, status) {
        layoutElements = JSON.parse(data).layout;
        $.get("/war/trainpositions.json", function(data, status) {
            var trains = JSON.parse(data).trains;
            updateLayout(layoutElements, trains);
        });
    });
}

function placeTrainPositions(trains) {
    var s;
    for(s = 0; s < trains.length; ++s) {
        var shp = trains[s].loco;
        var img = shapes[shp.shape];
        if(img) {
            ctx.fillStyle = bgColor;
            ctx.putImageData(img.imagedata, shp.x * 9, shp.y * 9);
        }
        shp = result.trains[s].car;
        if(!shp)
            continue;
        img = shapes[shp.shape];
        if(img) {
            ctx.fillStyle = bgColor;
            ctx.putImageData(img.imagedata, shp.x * 9, shp.y * 9);
        }
    }
}


function getOptions() {
    $.get("/war/options.yaml", function(data, status) {
        tdOptions = YAML.parse(data).options
        var s;
        for (s = 0; s < tdOptions.length; ++s) {
            var opt = tdOptions[s];
            if(opt.id == 'background') {
                bgColor = 'rgba(' + opt.value + ', 1)';
            }
        }
//        getLayout();
    }).fail(function(e) {
    	showError("/war/options.yaml failed: " + e.responseText);
    });
}

    $(document).ready(function() {
        $.getJSON("/war/shapes.json", function(data, status) {
        	var l = document.getElementById("divLayout");
        	if(!l) { getOptions(); return; }
            l.style.width = "" + data.canvas.width + "px";
            l.style.height = "" + data.canvas.height + "px";
            var c = document.getElementById("canvas");
            c.width = data.canvas.width;
            c.height = data.canvas.height;
            c.style.width = "" + data.canvas.width + "px";
            c.style.height = "" + data.canvas.height + "px";

            ctx = c.getContext("2d");
            var result = data.shapes;
            var s;
            for(s = 0; s < result.length; ++s) {
                var shp = result[s];
                var r;
                var img = ctx.createImageData(shp.width, shp.height);
                for(r = 0; r < shp.rows.length; ++r) {
                    var row = shp.rows[r];
                    var i;
                    for(i = 0; i < shp.width * 4; ++i) {
                        img.data[r * shp.width * 4 + i] = row[i];
                    }
                }
                shp.imagedata = img;
                shapes[shp.id] = shp;
            }
            getOptions();
        });
    });


var lastMousePos = { x: 0, y: 0 };
var inMouseReq = false;
var mouseAgain = undefined;


function initLayout() {
	canvasMouseMove = function(event) {
	    if (inMouseReq) {
	        mouseAgain = event;
	        return;
	    }
		var cell = toCellCoord(event);
		if(cell.x == lastMousePos.x && cell.y == lastMousePos.y) {
			return;
		}
		lastMousePos = cell;
		inMouseReq = true;
		var req = "/war/element.yaml?x=" + cell.x + "&y=" + cell.y;
		$.get(req, function (data) {
			var newStatus = " (" + cell.x + ", " + cell.y + ")";
	    	var el = YAML.parse(data);
	    	if(el) {
	    		var train = el.train;
	    		if(train) {
	    			newStatus = newStatus + " - train " + train.name + " to " + train.to + " " + train.status;
	    			if(train.etd) {
	    				newStatus = newStatus + " ETD: " + train.etd;
	    			}
	    		} else if (el.element) {
	    			var trk = el.element;
	    			var type = trk.type;
	    			if(type == 'track') {
	    				if(trk.name && trk.name != '') {
	    					newStatus = newStatus + " - " + trk.name;
	    				}
	    				if(trk.length > 0) {
	    					newStatus = newStatus + "  length: " + trk.length;
	    				}
	    				if(trk.speeds) {
	    					newStatus = newStatus + " " + trk.speeds;
	    				}
	    			} else if(type == 'signal') {
	    				newStatus = newStatus + " - signal ";
	    				if(trk.name && trk.name != '') {
	    					newStatus = newStatus + "  " + trk.name;
	    				}
	    				if(trk.controls) {
	    					newStatus = newStatus + " controls " + trk.controls;
	    				}
	    				newStatus = newStatus + " aspect " + trk.aspect;
	    			}
	    		}
	    	}
	    	$("#curStatus").html(newStatus);
	    	showTime();
	        inMouseReq = false;
	    }).fail(function(e) {
	        showError("/war/element.yaml failed: " + e.responseText);
	        inMouseReq = false;
		});
	};
	$("#canvas").mousemove(canvasMouseMove);
	$("#canvas").click(doCanvasClick);
	$('body').on('contextmenu', '#canvas', function(e) {
	    doCanvasClick(e);
	    return false;
	});
}

function reloadCanvas() {
//    $("#canvas").attr("src", "/war/canvas?i=" + new Date().getTime());
    getLayout();
}

function toCellCoord(event) {
    var ycoord = event.pageY - event.target.offsetTop;
    ycoord = event.offsetY;
    ycoord = Math.floor(ycoord / 9);
	var pos = { x: Math.floor(((event.pageX - event.target.offsetLeft) / 9)), y: ycoord };
	return pos;
}

function resumeRunning(prevStatus) {
	if (prevStatus.status.prev == 'running') {
		$.get('/war/play.yaml', function(res) {
			
		});
	}
}

function reverseTrain(train) {
	var prevStatus;
	$.get('/war/pause.yaml', function(prev) {
		prevStatus = YAML.parse(prev);
		BootstrapDialog.show({
            message: 'Reverse Train Direction?',
            animate: false,
            buttons: [{
                label: 'Reverse',
                action: function(dialogItself) {
                    dialogItself.close();
                    var cmd = "reverse " + train.name;
                    doCommandAndThen(cmd, function (res) {
                    	resumeRunning(prevStatus);
                    });
                }
            }, {
                label: 'Cancel',
                action: function(dialogItself){
                    dialogItself.close();
                }
            }]
        });
	});
}

function shuntTrain(train) {
	var prevStatus;
	$.get('/war/pause.yaml', function(prev) {
		prevStatus = YAML.parse(prev);
		BootstrapDialog.show({
            message: 'Proceed to next station?',
            animate: false,
            buttons: [{
                label: 'Proceed',
                action: function(dialogItself) {
                    dialogItself.close();
                    var cmd = "shunt " + train.name;
                    doCommandAndThen(cmd, function (res) {
                    	resumeRunning(prevStatus);
                    });
                }
            }, {
                label: 'Cancel',
                action: function(dialogItself){
                    dialogItself.close();
                }
            }]
        });
	});
}

function doCanvasClick(event) {
	var cell = toCellCoord(event);
	var req = "/war/element.yaml?x=" + cell.x + "&y=" + cell.y;
	$.get(req, function (data) {
    	var el = YAML.parse(data);
    	if (el) {
    		var train = el.train;
    		if(train) {
    			if(event.ctrlKey) { // ctrl+click: shunt train
    			    // just show train porperties
    			    /*
    				if(train.status == 'arrived') { // and not shunting
    					doAssignDialog(train.name);
    					return;
    				}
    				if(train.status == 'stopped' || train.status == 'waiting') {
    					shuntTrain(train);
    				} else {
    					// error: train must be stopped
    				}
    			*/
    			    return;
    			}
    			if(train.status == 'stopped' || train.status == 'waiting' || train.status == 'arrived') {
    			    if(event.which > 1) {
    			        if (train.status == "arrived")
    			            doAssignDialog(train.name, train['link']);
    			        else
    			            shuntTrain(train);
    			    } else {
    			        reverseTrain(train);
    			    }
    			} else {
    				// error: train must be stopped
    			}
    			return;
    		}
    	}
    	req = "/war/click?x=" + cell.x + "&y=" + cell.y + "&zoom=" + zooming + "&coord=" + coords;
    	req += "&shift=" + (event.shiftKey ? "1" : "0");
    	req += "&alt=" + (event.altKey ? "1" : "0");
    	req += "&ctrl=" + (event.ctrlKey ? "1" : "0");
    	req += "&btn=" + event.which;
    	$.getJSON(req, function(data) {
    		
    	}).fail(function() {
    		console.log("fail" + req);
    	});
/*    	
    	if(el.element.type == 'signal') {
    		if(event.ctrlKey) { // ctrl+click: shunt train
    			return;
    		}
    		
    	}
*/
    });
	/*
	req = "/war/click?x=" + cell.x + "&y=" + cell.y + "&zoom=" + zooming + "&coord=" + coords;
	req += "&shift=" + (event.shiftKey ? "1" : "0");
	req += "&alt=" + (event.altKey ? "1" : "0");
	req += "&ctrl=" + (event.ctrlKey ? "1" : "0");
	req += "&btn=" + event.which;
	
	// TODO: if shift, it should be handled locally:
	//    lshift on station -> show station schedule
	//    lshift on train -> show train info
	//    lshift on signal -> set itinerary start
	//    altclick on train -> shunt / assign
	$.getJSON(req, function(data) {
		
	}).fail(function() {
		console.log("fail");
	});
	*/
}


var trackDirs = [ 1, 2, 3, 4, 5, 6, 7, 8, 11, 12, 13, 14, 20, 21, 22, 23, 24, 25 ];
var sigNames = [ "sigRw", "sigRe", "sigRRw", "sigRRe", "sigRn", "sigRs", "sigRRn", "sigRRs" ];

function drawEditingTools() {
    var c = document.getElementById("editCanvas");
    ctx = c.getContext("2d");
    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, c.width, c.height);
    var i;
    drawingTools = 1;
    for(i = 0; i < trackDirs.length; ++i) {
        var elem = { type: 1, x: i, y: 0, dir: trackDirs[i], color: 0 };
        drawElement(elem);
    }
    for(i = 0; i <= 23; ++i) {
        var elem = { type: 2, x: i, y: 1, dir: i, color: 0 };
        drawElement(elem);
    }
    var x = trackDirs.length * 27 + 9;
    for(name in sigNames) {
        var img = shapes[sigNames[name]];
        if(img) {
            ctx.fillStyle = bgColor;
            ctx.putImageData(img.imagedata, x, 9);
            x += 27;
/*            if(shp.text) {
                drawText({ x: x + 3, y: 0, text: shp.text}, 0);
            }
*/        }
    }
    drawingTools = 0;
}

