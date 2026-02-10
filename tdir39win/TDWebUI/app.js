var myDocker;

function initialize() {
	myDocker = new wcDocker($("#clientArea"), {
		//themePath: 'My/themes/folder'
	});
	//initIcons();
	initializeViews();
	initTreeData();
}

var explorerTreeCount = 1;

function initializeViews() {
	myDocker.theme('ide');
	myDocker.registerPanelType("Explorer", {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  //var $container = $('#explorerDiv').html();
			  var targetId = 'explorerTree' + explorerTreeCount++;
			  var $container = '<div style="height: 100%"><div style="width:100%; background: #ffffff"><input type="text" id="treeSearch" width="200px"></div><div id="' + targetId + '" style="background: #ffffff; width:100%; height:100%; overflow: auto"></div></div>';
			  myPanel.layout().addItem($container);
			  updateExplorer('#' + targetId);
		  }
	});
	myDocker.registerPanelType("Viewer", {
		  //options: {'some optional object': 'that will be passed to the create function above'}
		  onCreate: function(myPanel, options) {
			  var $container = $('<div id="viewerDiv" style="width:100%;height:100%;">Views</div>');
			  myPanel.layout().addItem($container);
			  updateViewer();
		  }
	});
}

var treeData;

function initTreeData() {
	treeData = [ ];
	
	var i;
	var j;
	for (i = 0; i < 10; ++i) {
		var c = [];
		for (j = 0; j < 10; ++j) {
			var cn = { text: 'Child node ' + (i * 100 + j) };
			c.push(cn);
		}
		var n = { text: 'Node' + i, children: c };
		treeData.push(n);
	}
}

function updateExplorer(targetId) {
	var tree = new InspireTree({
		target: targetId,
		data:  treeData
/*
			function(node, resolve, reject) {
				var id = node ? node.id : 'root';
			  	return $.getJSON('a/url?id=' + id));
			}
 */
	});
	document.querySelector('#treeSearch').addEventListener('keyup', function(event) {
		tree.search(event.target.value);
	});
}


function updateViewer() {
	
}