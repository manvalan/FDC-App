var layoutPanel;
var schedulePanel;
var alertsPanel;
var canvas;
var myDocker;
var curTime;
var editing;

var statusImg = [];

var optSchedShowCanceled = false;
var optSchedShowArrived = true;
var sched;
var schedRows;
var schedFilter = '';

var contents = {};
var labels = [];

function initAll(isDockers, lang) {
    labels['Schedule'] = "Schedule";
    labels['Alerts'] = "Alerts";
    labels['Layout'] = "Layout";
    labels['Station Schedule'] = "Station Schedule";
    labels['Train Schedule'] = "Train Schedule";
    labels['Switchboard'] = "Switchboard";
    labels['Info Scenario'] = "Info Scenario";
    labels['Late Data'] = "Late Data";
    labels['Time Distance'] = "Time Distance";
    labels['Platform Occupancy'] = "Platform Occupancy";
	if (isDockers) {
		myDocker = new wcDocker($("#clientArea"), {
			// themePath: 'My/themes/folder'
		});
    	initializeViews();
    }
    initIcons();
    if(!isDockers) {
    	$('#curStatus').html("");
    	initTables();
    }
    $.get("/TDWebUI/html/allDialogs.html", function(result) {
        $("#allDialogs").html(result);
        initButtons();
		registerToServer();
    });
}

function initializeViews() {
		canvas = $("#canvas");
		myDocker.theme('ide');
		
		// --------------------------------------------------------------------------------
	    // Register the top panel, this is the static panel at the top of the window
	    // that can not be moved or adjusted.  Note that this panel is marked as
	    // 'isPrivate', which means the user will not get the option to create more of these.
	    myDocker.registerPanelType('Top Panel', {
	      isPrivate: true,
	      onCreate: function(myPanel) {
	        // myPanel.layout().scene().css('padding', '5px');

	        // Constrain the sizing of this window so the user can't resize it.
	        myPanel.initSize(Infinity, 83);
	        myPanel.minSize(100, 83);
	        myPanel.maxSize(Infinity, 83);
	        myPanel.title(false);

	        // Do not allow the user to move or remove this panel, this will remove the title bar completely from the frame.
	        myPanel.moveable(false);
	        myPanel.closeable(false);
	        myPanel.scrollable(false, false);

	        $header = $("#fixedTopPanel").html();
	        
	        myPanel.layout().addItem($header);
	      }
	    });
		
		myDocker.registerPanelType(labels['Schedule'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $('#scheduleDiv').html(); //$('<div id="scheduleDiv" style="width:100%;height:100%;">Schedule</div>');
				  myPanel.layout().addItem($container);
				  updateSchedule();
			  }
			});
		myDocker.registerPanelType(labels['Alerts'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $('<div id="alertsDiv" style="width:100%;height:100%;">Alerts</div>');
			  myPanel.layout().addItem($container);
			  updateAlerts();
		  }
		});
		myDocker.registerPanelType(labels['Layout'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $("#canvasDiv").html();
			  myPanel.layout().addItem($container);
			  initLayout();
		  }
		});
		myDocker.registerPanelType(labels['Station Schedule'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $("#stationSchedule").html();
				  myPanel.layout().addItem($container);
				  updateStationSchedule();
			  }
			});
		myDocker.registerPanelType(labels['Train Schedule'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $("#trainSchedule").html();
				  myPanel.layout().addItem($container);
				  updateTrainsStop();
			  }
			});
		myDocker.registerPanelType(labels['Switchboard'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $("#switchBoardDivSchedule").html();
				  myPanel.layout().addItem($container);
				  getSwitchboard();
			  }
			});
		myDocker.registerPanelType(labels['Info Scenario'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $("#infoScenario").html();
				  myPanel.layout().addItem($container);
				  updateInfoScenario();
			  }
			});
		myDocker.registerPanelType(labels['Late Data'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $('<div id="lateMinuteGraph" style="width:100%;height:100%;">Late Minutes</div>');
				  myPanel.layout().addItem($container);
				  loadLateData();
			  }
			});
		myDocker.registerPanelType(labels['Time Distance'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $("#timeDistance").html();
				  myPanel.layout().addItem($container);
				  loadTimeDistance();
			  }
			});
		myDocker.registerPanelType(labels['Platform Occupancy'], {
			  //options: {'some optional object': 'that will be passed to the create function above'}
			  onCreate: function(myPanel, options) {
				  var $container = $("#platformsOccupancy").html();
				  myPanel.layout().addItem($container);
				  loadPlatforms();
			  }
			});
	    
		var previousLayout = localStorage.getItem("dockerLayout");
		if (previousLayout !== undefined && previousLayout) {
			try {
				myDocker.restore(previousLayout);
			} catch (e) {
				defaultLayout();
			}
		} else {
			defaultLayout();
		}

//	    myDocker.addPanel('Top Panel', wcDocker.DOCK.TOP);
		window.onbeforeunload = function (e) {
			var savedLayout = myDocker.save();
			localStorage.setItem("dockerLayout", savedLayout);
			return null;
		};
}

var panelsContents = [];

function initializePanels() {
	canvas = $("#canvas");
	myDocker.theme('ide');
	
	// --------------------------------------------------------------------------------
    // Register the top panel, this is the static panel at the top of the window
    // that can not be moved or adjusted.  Note that this panel is marked as
    // 'isPrivate', which means the user will not get the option to create more of these.
    myDocker.registerPanelType('Top Panel', {
      isPrivate: true,
      onCreate: function(myPanel) {
        // myPanel.layout().scene().css('padding', '5px');

        // Constrain the sizing of this window so the user can't resize it.
        myPanel.initSize(Infinity, 83);
        myPanel.minSize(100, 83);
        myPanel.maxSize(Infinity, 83);
        myPanel.title(false);

        // Do not allow the user to move or remove this panel, this will remove the title bar completely from the frame.
        myPanel.moveable(false);
        myPanel.closeable(false);
        myPanel.scrollable(false, false);

//        $header = $("#fixedTopPanel").html();
        $header = panelsContents['fixedTop'];
        
        myPanel.layout().addItem($header);
      }
    });
 // --------------------------------------------------------------------------------
    // Register the creation panel that allows users to drag-drop custom elements
    // to create panels in docker.
    myDocker.registerPanelType('Creation Panel', {
      faicon: 'plus-square',
      onCreate: function(myPanel) {
    	  /*
        // Retrieve a list of all panel types, that are not marked as private.
        var panelTypes = myDocker.panelTypes(false);
        for (var i = 0; i < panelTypes.length; ++i) {
          // Retrieve more detailed information about the panel.
          var info = myDocker.panelTypeInfo(panelTypes[i]);

          // We want to show the panel icon, if it exists.
          var $icon = $('<div class="wcMenuIcon" style="margin-right: 15px;">');
          if (info.icon) {
            $icon.addClass(info.icon);
          }
          if (info.faicon) {
            $icon.addClass('fa fa-menu fa-' + info.faicon + ' fa-lg fa-fw');
          }

          // Now create the item using our theme's button style, but add a few styles of our own.
          var $item = $('<div class="wcCreatePanel wcButton">');
          $item.css('padding', 5)
            .css('margin-top', 5)
            .css('margin-bottom', 5)
            .css('border', '2px solid black')
            .css('border-radius', '10px')
            .css('text-align', 'center');

          // Set our item content and insert the icon.
          $item.text(panelTypes[i]);
          $item.data('panel', panelTypes[i]);
          $item.prepend($icon);
          myPanel.layout().addItem($item, 0, i+1);
        }
    	   */
        // Add a stretched element that will push everything to the top of the layout.
        //myPanel.layout().addItem($('<div>'), 0, i+1).stretch(undefined, '100%');
    	  var $menu = "<div><ul><li>One</li><li>Two</li><li>Three</li></ul></div>";
        myPanel.layout().addItem($menu);
      }
    });

	
	myDocker.registerPanelType(labels['Schedule'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $('#scheduleDiv').html(); //$('<div id="scheduleDiv" style="width:100%;height:100%;">Schedule</div>');
			  myPanel.layout().addItem($container);
			  updateSchedule();
		  }
		});
	myDocker.registerPanelType(labels['Alerts'], {
	  //options: {'some optional object': 'that will be passed to the create function above'}
	  onCreate: function(myPanel, options) {
		  var $container = $('<div id="alertsDiv" style="width:100%;height:100%;">Alerts</div>');
		  myPanel.layout().addItem($container);
		  updateAlerts();
	  }
	});
	myDocker.registerPanelType(labels['Layout'], {
	  //options: {'some optional object': 'that will be passed to the create function above'}
	  onCreate: function(myPanel, options) {
		  var $container = $("#canvasDiv").html();
		  myPanel.layout().addItem($container);
		  initLayout();
	  }
	});
	myDocker.registerPanelType(labels['Station Schedule'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $("#stationSchedule").html();
			  myPanel.layout().addItem($container);
			  updateStationSchedule();
		  }
		});
	myDocker.registerPanelType(labels['Train Schedule'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $("#trainSchedule").html();
			  myPanel.layout().addItem($container);
			  updateTrainsStop();
		  }
		});
	myDocker.registerPanelType(labels['Switchboard'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $("#switchBoardDivSchedule").html();
			  myPanel.layout().addItem($container);
			  getSwitchboard();
		  }
		});
	myDocker.registerPanelType(labels['Info Scenario'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $("#infoScenario").html();
			  myPanel.layout().addItem($container);
			  updateInfoScenario();
		  }
		});
	myDocker.registerPanelType(labels['Late Data'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $('<div id="lateMinuteGraph" style="width:100%;height:100%;">Late Minutes</div>');
			  myPanel.layout().addItem($container);
			  loadLateData();
		  }
		});
	myDocker.registerPanelType(labels['Time Distance'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $("#timeDistance").html();
			  myPanel.layout().addItem($container);
			  loadTimeDistance();
		  }
		});
	myDocker.registerPanelType(labels['Platform Occupancy'], {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $("#platformsOccupancy").html();
			  myPanel.layout().addItem($container);
			  loadPlatforms();
		  }
		});
    
    $.get( "html/fixedTop.html", function( data ) {
    	panelsContents['fixedTop'] = data;
    }).done(function() {

        myDocker.addPanel('Top Panel', wcDocker.DOCK.TOP);
//        var creationPanel = myDocker.addPanel('Creation Panel', wcDocker.DOCK.LEFT, wcDocker.COLLAPSED, { h:'10%', w:'10%'});

        var previousLayout = localStorage.getItem("dockerLayout");
    	if (previousLayout !== undefined && previousLayout) {
    		try {
//    			myDocker.restore(previousLayout);
    		} catch (e) {
//    			defaultLayout();
    		}
    	} else {
//    		defaultLayout();
    	}

    }).fail(function(e) {
        showError("html/fixedTop.html failed: " + e.responseText);
    });

//    myDocker.addPanel('Top Panel', wcDocker.DOCK.TOP);
	window.onbeforeunload = function (e) {
		var savedLayout = myDocker.save();
		localStorage.setItem("dockerLayout", savedLayout);
		return null;
	};
	initButtons();

//	setInterval(reloadAllViews, 1000);
	registerToServer();
}

function initTables() {
    initLayout();
    $('#tabGlobal a').on('show.bs.tab', function() {
        setPollUrl('status,trains')
    });
    $('#tabLayout a').on('show.bs.tab', function() {
        setPollUrl('status,trains,layout')
    });
    $('#tabStation a').on('show.bs.tab', function() {
        setPollUrl('status')
        updateStationSchedule();
    });
    $('#tabStops a').on('show.bs.tab', function() {
        updateTrainsStop();
        setPollUrl('status')
    });
    $('#tabInfoScenario a').on('show.bs.tab', function() {
        setPollUrl('status,info')
    });
    $('#tabLateMin a').on('show.bs.tab', function() {
        loadLateData();
        setPollUrl('status')
    });
    $('#tabTimeDistance a').on('show.bs.tab', function() {
        loadTimeDistance();
        setPollUrl('status')
    });
    $('#tabPlatforms a').on('show.bs.tab', function() {
        loadPlatforms();
        setPollUrl('status')
    });
    $('#tabAlerts a').on('show.bs.tab', function() {
        setPollUrl('status,alerts')
    });
    $('#tabSwitchboards a').on('show.bs.tab', function() {
        setPollUrl('status,sboard')
    });
    $('#tabPreferences a').on('show.bs.tab', function() {
        setPollUrl('status')
    });
    registerToServer();
}

function initIcons() {
    statusImg['class0'] = 'img/blue_ball.png';
    statusImg['class1'] = 'img/green_ball.png';
    statusImg['class2'] = 'img/orange_ball.png';
    statusImg['class3'] = 'img/purple_ball.png';
    statusImg['class4'] = 'img/red_ball.png';
    statusImg['class5'] = 'img/yellow_ball.png';
    statusImg['class6'] = 'img/grey_ball.png';
    statusImg['class7'] = 'img/yellow_ball.png';
    
    initLocalizations();
}

var translations;

function initLocalizations() {
    var i;
    $.get( "/war/translations.yaml", function( data ) {
        translations = YAML.parse(data);
        if(translations) {
            $('.tdlocal').each(function(i, obj) {
                for(i = 0; i < translations.length; ++i) {
                    if($(obj).text() == translations[i].en) {
                        $(obj).html(translations[i].loc);
                        break;
                    }
                }
            });
        }
    }).done(function() {
        console.log("done");
    }).fail(function(e) {
        showError("/war/translations.yaml failed: " + e.responseText);
    });
}

function initButtons() {
	$("#btnAssign").on('click', function() {
		doAssign();
	});
	$("#btnAssignShunt").on('click', function() {
		doAssignShunt();
	});
	$("#btnShunt").on('click', function() {
		doShunt();
	});
	$("#btnReverse").on('click', function() {
		doReverse();
	});
	$("#btnAssignReverse").on('click', function() {
		doAssignReverse();
	});
	$("#btnSplit").on('click', function() {
		doSplit();
	});
    $('#schedSearchInput').on('input', function() { 
        schedFilter = $(this).val() // get the current value of the input field.
        updateSchedule();
    });
    $("a[href='#prefsDiv']").on('shown.bs.tab', function (e) {
//    	var target = $(e.target).attr("href") // activated tab
//    	alert(target);
    	doPreferences(true);
    });

    $("#startStopButton").on('click', function() {
        doRunStop();
    });
    $("#slowerButton").on('click', function() {
        doSlow();
    });
    $("#fasterButton").on('click', function() {
        doFast();
    });
    $("#toNextButton").on('click', function() {
        doSkip();
    });
    $("#setSigToGreenMenu").on('click', function() {
        doSetSignals();
    });
    $("#selectItinMenu").on('click', function() {
        doSelectItin();
    });
    $("#editMenu").on('click', function() {
        doEdit();
    });
    $("#restartMenu").on('click', function() {
        doRestart();
    });

}

var firstTime;
var pollUrl;
var lastSimInfo;

function setPollUrl(parts) {
    pollUrl = "/poll/?parts=" + parts;
}

function updateAll(data) {
    $("#scheduleStatusRow").html("");
    showTime();
    if(data.trains)
        updateScheduleView(data.trains);
    if(data.alerts)
        updateAlertsView(data.alerts);
    if(data.status) {
        curTime = data.status.time;
        curMult = data.status.mult;
        if(data.status.editing != undefined && data.status.editing) {
            $("#simStatusRow").hide();
            $("#simEditRow").show();
            editing = 1;
            updateEditStatusView();
        } else {
            $("#simStatusRow").show();
//            $("#simEditRow").hide();
            editing = 0;
            if(data.status.running != undefined) {
                var oldcl;
                var newcl;
                if(data.status.running == "1") {   // when running, we want to show the pause icon
                    oldcl = "glyphicon-play";
                    newcl = "glyphicon-pause";
                } else {                    // when stopped, we want to show the play icon
                    oldcl = "glyphicon-pause";
                    newcl = "glyphicon-play";
                }
                if($("#startStopIcon").hasClass(oldcl)) {
                    $("#startStopIcon").removeClass(oldcl).addClass(newcl);
                }
            }
        	updateRunStatusView(data.status);
        }
    }
    if(data.layout)
        updateLayout(data.layout, data.trains);
    if(data.switchboards) {
        updateSwitchboardsData(data.switchboards);
    }
    if(data.info) {
        /*
    	var info = "";
    	var i;
    	for(i = 0; i < data.info.length; ++i)
    		info += data.info[i] + "\n";
    	*/
        if(lastSimInfo == data.info)
            return;
        lastSimInfo = data.info;
        var info = "<iframe width='100%' height='800px' src='/sim/info/" + data.info + "'>IFRAME support needed to show simulation information</iframe>";
    	$("#infoScenario").html(info);
    }
}

function pollServer() {
    $.getJSON(pollUrl, function ( state ) {
        if(state.quitting) {
            showError("Simulator server has exited.").
            return;
        }
        updateAll(state);
        pollServer(); // wait next time slice
    }).fail(function(err) {
        showError(pollUrl + " failed: " + err.responseText);
    });
}

function registerToServer() {
    setPollUrl("trains,status,layout,alerts"); // default, will be changed based on currently selected tab / visible views 
    pollServer();
}

function classToState(cl) {
	if (cl == 'class0') return 'ready';
	if (cl == 'class1') return 'running';
	if (cl == 'class2') return 'stopped';
	if (cl == 'class3') return 'delayed';
	if (cl == 'class4') return 'waiting';
	if (cl == 'class5') return 'derailed';
	if (cl == 'class6') return 'arrived';
	if (cl == 'class7') return 'starting';
	return cl;
}

function defaultLayout() {
	// Put Panel1 into the docking layout, since it is the first panel,
	// it will always fill the entire area regardless of what docking
	// position you request.
	// The panel itself may have an initial size, but you may want more
	// control over that.
	myDocker.clear();

    layoutPanel = myDocker.addPanel(labels['Layout'], wcDocker.DOCK.LEFT);

	schedulePanel = myDocker.addPanel(labels['Schedule'], wcDocker.DOCK.BOTTOM);

	// Once we added a panel, we can use it as a target for another panel.
	alertsPanel = myDocker.addPanel(labels['Alerts'], wcDocker.DOCK.RIGHT, schedulePanel);
}

var onSchedResized = function(e){
	//var columns = $(e.currentTarget).find("th");
	//var msg = "columns widths: ";
	//columns.each(function(){ msg += $(this).width() + "px; "; })
	//$("#sample2Txt").html(msg);
};

function updateSchedule() {
		$.getJSON( "/war/trains.json", function( data ) {
			updateScheduleView(data.trains);
		}).done(function() {
			console.log("done");
		}).fail(function(e) {
			showError("/war/trains.json failed: " + e.responseText);
		});
}

function updateAlerts() {
	
}

var simTimeSpan;
var curMultSpan;
var curMult;

function showTime() {
    if(!simTimeSpan)
        simTimeSpan = document.getElementById('simTimeSpan');
    if(simTimeSpan && curTime)
    	simTimeSpan.innerHTML = curTime;
    if(!curMultSpan)
        curMultSpan = document.getElementById('timeMult');
    if(curMultSpan && curMult)
        curMultSpan.innerHTML = curMult + " x";
}

function showError(msg) {
	$('#simAlertRow').html(msg);
}

function reloadAllViews() {
}

function schedRow(i, val) {
    var src = statusImg[val.state];
    var img = "";
    if (src)
        img = "<img src='" + src + "' width='16px'></img>&nbsp;";
    var r = "<tr id='r" + i + "' class='" + val.state + "' ondblclick='dblclkSchedule(\"" + val.name + "\", \"" + val.link + "\");'><td >" + img + val.name + "</td><td>" + val.timeIn + "</td><td>" + val.entry + "</td><td>" + val.timeOut + "</td><td>" + val.exit + "</td><td>" + val.speed + "</td><td>"+ val.status + "</td><td>" + val.late + "</td><td>" + val.delay +"</td></tr>";
    return r;
}

function updateScheduleView(trains) {
    var i;
    var val;
    var filtered = [];
    if(schedFilter.length > 0) {
        for(i = 0; i < trains.length; ++i) {
            var tr = trains[i];
            if(tr.name.indexOf(schedFilter) >= 0 ||
                    tr.status.indexOf(schedFilter) >= 0 ||
                    tr.timeIn.indexOf(schedFilter) >= 0 ||
                    tr.timeOut.indexOf(schedFilter) >= 0 ||
                    tr.entry.indexOf(schedFilter) >= 0 ||
                    tr.exit.indexOf(schedFilter) >= 0 ||
                    tr.speed.indexOf(schedFilter) >= 0 ||
                    tr.late.indexOf(schedFilter) >= 0 ||
                    tr.delay.indexOf(schedFilter) >= 0) {
                filtered.push(tr);
            }
        }
    } else {
        filtered = trains;
    }
    if(sched && sched.length != filtered.length) {
        sched = null;
    }
    if(!sched) {
	    var items = [];
	    i = 0;
	    sched = filtered;
	    for (i = 0; i < sched.length; ++i) {
	        val = sched[i];
	        items.push(schedRow(i, val));
	    }
	    $("#schedTab tbody").html(items.join("\n"));
	    schedRows = [];
    } else {
        if(schedRows.length == 0) {
            for(i = 0; i < sched.length; ++i) {
                schedRows.push(document.getElementById('r' + i));
            }
        }
        for(i = 0; i < sched.length; ++i) {
            var old = sched[i];
            var cur = filtered[i];
            if(old.state != cur.state || old.timeIn != cur.timeIn || old.timeOut != cur.timeOut || old.speed != cur.speed || old.status != cur.status || old.late != cur.late || old.delay != cur.delay) {
                sched[i] = cur;
                val = cur;
                var newRow = schedRow(i, val);
                var rowElement = schedRows[i];
                if(rowElement) {
                    schedRows[i].innerHTML = newRow;
                } else {
                    console.log("element is null " + i);
                }
            }
        }
    }
    $('#schedTab').on('click', 'tbody tr', function(event) {
	    $(this).addClass('selectedItem').siblings().removeClass('selectedItem');
		if(event.ctrlKey) { // ctrl+click: show action dialog
		}
	    // alert($(this).cell[0].innerText);
	});
	$("#schedTab").colResizable({
	    postbackSafe: true,
	    liveDrag:true });
//			gripInnerHtml:"<div class='grip'></div>", 
//			draggingClass:"dragging", 
//			onResize:onSchedResized});
}

var selectedTrainInSchedule;

function findTrain(name) {
	if (!sched.length) // impossible
		return;
	var s;
	for (s = 0; s < sched.length; ++s) {
		var tr = sched[s];
		if (tr.name == name)
			return tr;
	}
	return null;
}

function dblclkSchedule(name, link) {
	doAssignDialog(name, link);
}

function doAssignDialog(name, link) {
	selectedTrainInSchedule = link;
	$.get( "/war/assigninfo.yaml?t=" + link, function( data ) {
		var items = [];
		var info;
		if (data != "") {
			info = YAML.parse(data);
			
			$.each(info.candidates, function( key, val ) {
				var notes = val.notes ? val.notes : "";
				items.push("<tr><td class='asgTrainName' id='" + val.link + "'>" + val.train + "</td><td>" + val.arr + "</td><td>" + val.dep + "</td><td>" + val.from + "</td><td>" + val.to + "</td><td>" + notes + "</td></tr>\n");
			});
			$("#assignCandidatesTable tbody").html(items.join(""));
			$('#assignCandidatesTable').on('click', 'tbody tr', function(event) {
				$(this).addClass('selectedItem').siblings().removeClass('selectedItem');
				// alert($(this).cell[0].innerText);
				$("#btnAssign").prop('disabled', state != 'arrived');
				$("#btnAssignShunt").prop('disabled', state != 'arrived');
				$("#btnAssignReverse").prop('disabled', state != 'arrived');
			});
			setHeaderColumnsWidths("#assignCandidatesTable");
		}
		var tr = findTrain(name);
		var state = classToState(tr.state);
		$("#btnAssign").prop('disabled', true); // disaled until user selects a train from the list
		$("#btnAssignShunt").prop('disabled', true);
		$("#btnAssignReverse").prop('disabled', true);
		$("#btnShunt").prop('disabled', state != 'arrived' && state != 'stopped');
		$("#btnSplit").prop('disabled', state != 'arrived' && state != 'stopped');
		$("#btnReverse").prop('disabled', state != 'arrived' && state != 'stopped' && state != 'waiting');
		var h = document.documentElement.clientHeight * 0.75;
		$("#assignCandidatesTable tbody").height(h);
		$('#assignDialog').modal('show');
        if(info && info.link) {
            $("#" + info.link).click();
        }
	}).done(function() {
	}).fail(function(e) {
		showError("/war/assigninfo.yaml failed: " + e.responseText);
	});
}

function updateAlertsView(alerts) {
	  var items = [];
	  $.each(alerts, function( key, val ) {
		  items.push(val + "<br>");
	  });
	  $("#alertsDiv").html(items.join(""));
}

function updateRunStatusView(status) {
	$("#pointsRow").html(status.timemsg + " - " + status.points);
}

function updateEditStatusView() {
    drawEditingTools();
}

function doCommand(cmd) {
	$.getJSON("/war/do?" + cmd, function(data) {
		
	}).done(function() {
		reloadAllViews();
		console.log("done");
	}).fail(function(e) {
		showError("/war/do?" + cmd + " failed: " + e.responseText);
	});
}

function doCommandAndThen(cmd, next) {
	$.getJSON("/war/do?" + cmd, function(data) {
		next(data);
	}).done(function() {
		reloadAllViews();
		console.log("done");
	}).fail(function(e) {
		showError("/war/do?" + cmd + " failed: " + e.responseText);
	});
}

function doEdit() {
    
}

function itineraryDialog() {
	$.get( "/war/itineraries.yaml", function( data ) {
		var itineraries = YAML.parse(data);
		var items = [];

		$.each(itineraries.itineraries, function( key, val ) {
			  items.push("<tr><td class='itinName' id='" + val.name + "'>" + val.name + "</td><td>" + val.from + "</td><td>" + val.to + "</td><td>" + val.next + "</td></tr>\n");
		});
		$("#itineraryDialogTable tbody").html(items.join(""));
		$('#itineraryDialogTable').on('click', 'tbody tr', function(event) {
		    $(this).addClass('selectedItem').siblings().removeClass('selectedItem');
		    // alert($(this).cell[0].innerText);
		});
		$('#itinSelectButton').on('click', function(event) {
			var table = $("#itineraryDialogTable");
			var rows = $(table).find(".selectedItem");
			var col = $(rows).find(".itinName");
			var itinName = col.attr('id');
			var cmd = "itinerary " + itinName;
			doCommand(cmd);
		});
		var h = document.documentElement.clientHeight * 0.75;
		$("#itineraryDialogTable tbody").height(h);
		$('#itineraryDialog').modal('show');
		setHeaderColumnsWidths("#itineraryDialogTable");
	}).done(function() {
	}).fail(function(e) {
		showError("/war/itineraries.yaml failed: " + e.responseText);
	});
}

var tdOptions;

function doPreferences(fromModal) {
	$("#savePreferencesButton").on("click", function() {
		var cnt = 0; // color count
		$.each(tdOptions.options, function( key, val ) {
			if(val.type == 'color') {
				var r = $("#color-r-" + cnt).val();
				var g = $("#color-g-" + cnt).val();
				var b = $("#color-b-" + cnt).val();
				var rgb = (r << 16) | (g << 8) | b;
				doCommand('option ' + val.id + "=" + rgb);
				++cnt;
			} else if(val.type == 'string' || val.type == 'file') {
				val.value = $("#" + val.id).val();
				if (val.value != val.oldvalue) {
					val.oldvalue = val.value;
					doCommand('option ' + val.id + "=" + val.value);
				}
			} else {
				val.value = $("#" + val.id).prop('checked');
				if (val.value != val.oldvalue) {
					val.oldvalue = val.value;
					doCommand('option ' + val.id + "=" + (val.value ? '1' : '0'));
				}
			}
		});
	});
	$.get( "/war/options.yaml", function( data ) {
		tdOptions = YAML.parse(data);
		var items = [];
		var cnt = 0;
		$.each(tdOptions.options, function( key, val ) {
			var chkd = "";
			if (val.type == 'bool') {
				if (val.value)
					chkd = "checked ";
				val.oldvalue = val.value;
				items.push("<div class='checkbox'><label><input type='checkbox' id='" + val.id + "' " + chkd + ">" + val.desc + "</label></div>");
			} else if(val.type == 'string' || val.type == 'int' || val.type == 'file') {
				val.oldvalue = val.value;
 	 		    items.push('<div class="form-group row">');
 	 		    items.push('<label for="inputEmail3" class="col-sm-4 form-control-label">' + val.desc + '</label>');
// 	 		    items.push('<div class="col-sm-9">');
 	 		    items.push('<input type="text" class="form-inline col-sm-7" id="' + val.id + '" value="' + val.value + '">');
// 	 		    items.push("</div>");
 	 		    items.push("</div>");
			} else if(val.type == 'color') {
				var rgb = val.value.split(',');
 	 		    items.push('<div class="form-group row">');
 	 		    items.push('<label for="inputEmail3" class="col-sm-4 form-control-label">' + val.desc + '</label>');
 	 		    items.push('<div class="col-sm-8">');
 	 		    items.push('<input type="text" class="form-inline" id="color-r-' + cnt + '" placeholder="Red" value="' + rgb[0] + '">&nbsp;');
 	 		    items.push('<input type="text" class="form-inline" id="color-g-' + cnt + '" placeholder="Green" value="' + rgb[1] + '">&nbsp;');
 	 		    items.push('<input type="text" class="form-inline" id="color-b-' + cnt + '" placeholder="Blue" value="' + rgb[2] + '">&nbsp;&nbsp;');
 	 		    items.push('<input type="text" class="form-inline" id="color-picker-' + cnt + '" value="rgb(' + val.value + ')" />');
 	 		    items.push("</div>");
 	 		    items.push("</div>");
 	 			cnt += 1;
			}
		});
		$("#preferencesBody").html(items.join(""));
		cnt = 0;
		$.each(tdOptions.options, function( key, val ) {
			if(val.type == 'color') {
 	 			doColorPicker(cnt, val.value);
 	 			cnt += 1;
			}
		});
		if(fromModal) {
			$('#preferencesDialog').modal({ show: true, keyboard: true });
		} else {
//			$("#preferencesBody").html(items.join(""));
		}
	}).done(function() {
	}).fail(function(e) {
		showError("/war/options.yaml failed: " + e.responseText);
	});
}

function doColorPicker(name, colr) {
	var r = (colr >> 16) & 0xff;
	var g = (colr >> 8) & 0xff;
	var b = colr & 0xff;
	$('#color-picker-' + name).spectrum({
	    showInput: true,
	    className: "full-spectrum",
	    showInitial: true,
	    showPalette: true,
	    showSelectionPalette: true,
	    maxSelectionSize: 10,
	    preferredFormat: "hex",
	    localStorageKey: "spectrum.demo",
	    move: function (color) {
	        
	    },
	    show: function () {
	    
	    },
	    beforeShow: function () {
	    
	    },
	    hide: function () {
	    
	    },
	    change: function(rgb) {
	    	$("#color-r-" + name).val(Math.floor(rgb._r));
	        $("#color-g-" + name).val(Math.floor(rgb._g));
	        $("#color-b-" + name).val(Math.floor(rgb._b));
	    },
	    palette: [
	        ["rgb(0, 0, 0)", "rgb(67, 67, 67)", "rgb(102, 102, 102)",
	        "rgb(204, 204, 204)", "rgb(217, 217, 217)","rgb(255, 255, 255)"],
	        ["rgb(152, 0, 0)", "rgb(255, 0, 0)", "rgb(255, 153, 0)", "rgb(255, 255, 0)", "rgb(0, 255, 0)",
	        "rgb(0, 255, 255)", "rgb(74, 134, 232)", "rgb(0, 0, 255)", "rgb(153, 0, 255)", "rgb(255, 0, 255)"], 
	        ["rgb(230, 184, 175)", "rgb(244, 204, 204)", "rgb(252, 229, 205)", "rgb(255, 242, 204)", "rgb(217, 234, 211)", 
	        "rgb(208, 224, 227)", "rgb(201, 218, 248)", "rgb(207, 226, 243)", "rgb(217, 210, 233)", "rgb(234, 209, 220)", 
	        "rgb(221, 126, 107)", "rgb(234, 153, 153)", "rgb(249, 203, 156)", "rgb(255, 229, 153)", "rgb(182, 215, 168)", 
	        "rgb(162, 196, 201)", "rgb(164, 194, 244)", "rgb(159, 197, 232)", "rgb(180, 167, 214)", "rgb(213, 166, 189)", 
	        "rgb(204, 65, 37)", "rgb(224, 102, 102)", "rgb(246, 178, 107)", "rgb(255, 217, 102)", "rgb(147, 196, 125)", 
	        "rgb(118, 165, 175)", "rgb(109, 158, 235)", "rgb(111, 168, 220)", "rgb(142, 124, 195)", "rgb(194, 123, 160)",
	        "rgb(166, 28, 0)", "rgb(204, 0, 0)", "rgb(230, 145, 56)", "rgb(241, 194, 50)", "rgb(106, 168, 79)",
	        "rgb(69, 129, 142)", "rgb(60, 120, 216)", "rgb(61, 133, 198)", "rgb(103, 78, 167)", "rgb(166, 77, 121)",
	        "rgb(91, 15, 0)", "rgb(102, 0, 0)", "rgb(120, 63, 4)", "rgb(127, 96, 0)", "rgb(39, 78, 19)", 
	        "rgb(12, 52, 61)", "rgb(28, 69, 135)", "rgb(7, 55, 99)", "rgb(32, 18, 77)", "rgb(76, 17, 48)"]
	    ]
	});
}

function updateInfoScenario() {
	$.get( "/war/infoscenario", function( data ) {
		$("#infoScenario").html(data);
	}).done(function() {
		console.log("done");
	}).fail(function(e) {
		$("#infoScenario").html("<p>Could not retrieve the information about this scenario.<br>" + e);
	});
}

function getSwitchboard() {
	$("#switchBoardDiv").html('<iframe src="127.0.0.1:8999/switchboard/Partenze"></iframe>');
/*	$.get( "/switchboard/Partenze", function( data ) {
		$("#switchBoardDiv").html(data);
	}).done(function() {
	}).fail(function() {
		$("#switchBoardDiv").html("<p>Could not retrieve the switchboard.");
	});
*/
	}


function doRunStop() {
	doCommand("run");
}
function doFast() {
	doCommand("fast");
}
function doSlow() {
	doCommand("slow");
}
function doSkip() {
	doCommand("skip");
}
function doSetSignals() {
    doCommand("greensigs");
}
function doSelectItinerary() {
	itineraryDialog();
}

function doRestart() {
    var prevStatus;
    $.get('/war/pause.yaml', function(prev) {
        prevStatus = YAML.parse(prev);
        BootstrapDialog.show({
            message: 'Restart simulation?',
            animate: false,
            buttons: [{
                label: 'Restart',
                action: function(dialogItself) {
                            dialogItself.close();
                            doCommand("t0!");
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

function doSelectItin() {
    doSelectItinerary();
}

function getSelectedTrainFromAssignCandidates() {
	var table = $("#assignCandidatesTable");
	var rows = $(table).find(".selectedItem");
	var col = $(rows).find(".asgTrainName");
	return col.attr('id');
}

function doAssign() {
	var sel = getSelectedTrainFromAssignCandidates();
	var cmd = "assign \b" + selectedTrainInSchedule + "\b,\b"  + sel;
	doCommand(cmd);
}

function doAssignShunt() {
	var sel = getSelectedTrainFromAssignCandidates();
	var cmd = "assign \b" + selectedTrainInSchedule + "\b,\b"  + sel;
	doCommand(cmd);
	cmd = "shunt " + sel;
	doCommand(cmd);
}

function doShunt() {
	var cmd = "shunt \b" + selectedTrainInSchedule;
	doCommand(cmd);
}

function doReverse() {
    var cmd = "reverse \b" + selectedTrainInSchedule;
    doCommand(cmd);
}

function doAssignReverse() {
	var sel = getSelectedTrainFromAssignCandidates();
	var cmd = "assign \b" + selectedTrainInSchedule + ","  + sel;
	doCommand(cmd);
	cmd = "reverse " + sel;
	doCommand(cmd);
}

function doSplit() {
	$("#doSplitButton").on("click", function() {
		var dist = $("#splitText").val();
		doCommandAndThen('split \b' + selectedTrainInSchedule + "\b," + dist, 
			function (res) {
	        	doShunt();
	        });
	});
	$('#splitDialog').modal({ show: true, keyboard: true });
}

function reloadSchedule() {
    var items = [];
    $.each(trains, function( key, val ) {
        items.push("<tr class='" + val.state + "' ondblclick='dblclkSchedule(\"" + val.name + "\");'><td >" + val.name + "</td><td class='" + val.state + "' >" + val.timeIn + "</td><td>" + val.entry + "</td><td>" + val.timeOut + "</td><td>" + val.exit + "</td><td>" + val.speed + "</td><td>"+ val.status + "</td><td>" + val.late + "</td><td>" + val.delay +"</td></tr>");
    });
    $("#schedTab tbody").html(items.join("\n"));
}

function setHeaderColumnsWidths(element) {
	setTimeout(function() {
        // Change the selector if needed
        var $table = $(element),
            $bodyCells = $table.find('tbody tr:first').children(),
            colWidth;

        // Get the tbody columns width array
        colWidth = $bodyCells.map(function() {
            return $(this).width();
        }).get();

        // Set the width of thead columns
        $table.find('thead tr').children().each(function(i, v) {
            $(v).width(colWidth[i]);
        });
	}, 200);
}
