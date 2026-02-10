var selectedSwitchboardLink;    // TODO: make local to the view instance
var selectedSwitchboardNumber;
var sboards;

function updateSwitchboards() {
}

function updateSwitchboardsList(list, filtr) {
    
	var items = [];
	var i;
	if(!selectedSwitchboardNumber) // automatically select first (or only one) 
		selectedSwitchboardNumber = 0;
	for(i = 0; i < list.length; ++i) {
	    var val = list[i];
	    if(filtr && filtr.length > 0 && val.name.indexOf(filtr) < 0)
	        continue;
	    var cl = "'selectorItem'";
		items.push("<li class='selectorItem' onclick='onSelectedItem(\"" + val.link + "\", " + i + ");'>" + val.name + "</li>\n");
	};
	$("#switchboards .selectorList").html(items.join(""));
	selectItemInList(selectedSwitchboardNumber); // keep item selected across updates
}

// highlight the item that is currently selected

function selectItemInList(itemNr) {
    var i = 0;
	$("#switchboards .selectorItem").each(function() {
		if(i == itemNr) {
			this.style.color = "blue";
			$(this).css("font-weight", "bold")
		} else {
			this.style.color = "black";
			$(this).css("font-weight", "normal")
		}
		++i;
	});
}

// update right panel

function onSelectedItem(link, itemNr) {
    selectedSwitchboardLink = link;
    selectedSwitchboardNumber = itemNr;
	selectItemInList(itemNr);
    $('#switchboards .detailsFilter').on('input', function() {
        updateSwitchboardDetails();
    });
    updateSwitchboardDetails();
}

function onSboardCellSelected(x, y) {
	var i;
    var sb = sboards[selectedSwitchboardNumber];
    if(!sb)
    	return;
    for(i = 0; i < sb.cells.length; ++i) {
        var c = sb.cells[i];
        if(c.x == x && c.y == y) {
        	// we could use itinerary name instead of x,y
        	var cmd = 'switch ' + c.x + ',' + c.y + ' ' + sb.fname;
        	doCommand(cmd);
        	return;
        }	
    }
}

function updateSwitchboardDetails() {
    var schedFilter = $('#switchboards .details').val();
    var x, y;
	var i;
    var sb = sboards[selectedSwitchboardNumber];
    if(!sb) {
        var $container = $("#switchboardNone").html();
        $('#switchboards .details').html($container);
        return;
    }
    var table = "<table>";
    for (y = 0; y < 20; ++y) {
        var r = "<tr>";
        for(x = 0; x < 20; ++x) {
        	var tdattr = "class='sbcell'";
        	var span = "-";
        	if(sb) {
	            for(i = 0; i < sb.cells.length; ++i) {
	                var c = sb.cells[i];
	                if(c.x == x && c.y == y) {
	                    span = c.text;
	                    tdattr = " onclick='onSboardCellSelected(" + c.x + "," + c.y + ");' class='sbcell sb-" + c.class + "'";
	                    break;
	                }
	            }
        	}
            r += "<td " + tdattr + ">" + span + "</td>";
        }
        r += "</tr>\n";
        table += r;
    }
    table += "</table>\n";
    $('#switchboards .details').html(table);
}

function updateSwitchboardsData(data) {
    sboards = data;
    var sbnames = [];
    var i = 0;
    for (i = 0; i < sboards.length; ++i) {
        var sb = sboards[i];
        var sel = { name: sb.name, link: sb.name };
        sbnames.push(sel);
    }
    updateSwitchboardsList(sbnames, "");
    updateSwitchboardDetails();
}
