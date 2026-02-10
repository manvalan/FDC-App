var Window = function() {
	this.ident = 0;
	this.content = null;
	this.splitDir = '';  // 'v' or 'h'
	this.children = [ ]; // nodes of left,rigth or top/bottom
	this.sizes = [ ];   // size of left,right or top/bottom
};

var W = new Window();

function saveLayout() {
	localStorage['layout'] = JSON.stringify(W);
}

function restoreLayout() {
	var retrievedLayout = localStorage['layout'];
	if (retrievedLayout !== undefined && retrievedLayout)
		W = JSON.parse(retrievedObject);
}

function drawLayout() {
	var body = "";
	body = drawTree(W, body);
}

function drawTree(node) {
	if (node.children.length > 0) {
		var x = "";
		if(node.splitDir == 'v') {
			x = "<div class='split-pane fixed-left'>\n";
			x += "<div class='split-pane-component' id='left-component'>" + drawTree(node.children[0]) + "</div>\n";
			x += "<div class='split-pane-divider' id='v-divider'>\n";
			x += "<div class='split-pane-component' id='right-component'>" + drawTree(node.children[1]) + "</div>\n";
			x += "</div>";
			return x;
		} else {
			x = "<div class='split-pane fixed-top'>\n";
			x = "<div class='split-pane-component' id='top-component'>" + drawTree(node.children[0]) + "</div>\n";
			x += "<div class='split-pane-divider' id='h-divider'>\n";
			x += "<div class='split-pane-component' id='bottom-component'>" + drawTree(node.children[1]) + "</div>\n";
			x += "</div>";
			return x;
		}
	} else {
		return node.content;
	}
}