var layout;
var canvas;

function showLayout() {
	layout = document.getElementById("layout");
	layout.visibility = "visible";
}

function doReload() {
	var canvas = document.getElementById("canvas");
	canvas.src = "/war/canvas" + "?i=" + (Math.random() * 1000);
	setTimeout(doReload, 2000);
}

function onCanvasClick(event) {
	var coords = relMouseCoords(event);
	
}

function relMouseCoords(event) {
    var totalOffsetX = 0;
    var totalOffsetY = 0;
    var canvasX = 0;
    var canvasY = 0;
    var currentElement = canvas;

    do {
        totalOffsetX += currentElement.offsetLeft - currentElement.scrollLeft;
        totalOffsetY += currentElement.offsetTop - currentElement.scrollTop;
    } while(currentElement = currentElement.offsetParent)

    canvasX = event.pageX - totalOffsetX;
    canvasY = event.pageY - totalOffsetY;

    return {x:canvasX, y:canvasY}
}

function onLoaded() {
//	canvas = document.getElementById("canvas");
//	setTimeout(doReload, 2000);
//	 $().ready(function(){
//		   $("#MySplitter").splitter();
//		 });
}
